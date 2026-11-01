const mongoose = require('mongoose');
const TaskShare = require('../models/TaskShare');
const User = require('../models/User');
const { logActivity } = require('../services/taskService');
const { notifyTaskShared } = require('../services/notificationService');
const { sendTaskSharedEmails } = require('../services/emailService');

// GET /api/tasks/:id/shares (quyen xem)
const getShares = async (req, res, next) => {
  try {
    const shares = await TaskShare.find({ taskId: req.task._id })
      .populate('userId', 'fullName email avatarUrl')
      .populate('sharedBy', 'fullName email avatarUrl');

    const formattedShares = shares.map((s) => ({
      id: s._id.toString(),
      user: s.userId
        ? {
            id: s.userId._id.toString(),
            fullName: s.userId.fullName,
            email: s.userId.email,
            avatarUrl: s.userId.avatarUrl
          }
        : null,
      permission: s.permission,
      sharedBy: s.sharedBy
        ? {
            id: s.sharedBy._id.toString(),
            fullName: s.sharedBy.fullName,
            email: s.sharedBy.email
          }
        : null,
      createdAt: s.createdAt
    }));

    return res.status(200).json({
      message: 'Lay danh sach chia se thanh cong',
      shares: formattedShares
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/tasks/:id/shares (quyen chia se)
const createShares = async (req, res, next) => {
  try {
    const task = req.task;
    const { userIds, permission } = req.body;

    const allowedPermissions = ['viewer', 'editor'];
    if (!permission || !allowedPermissions.includes(permission)) {
      return res.status(400).json({ message: 'Quyen chia se phai la viewer hoac editor' });
    }

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'Danh sach userIds khong duoc de trong' });
    }

    // Kiem tra dinh dang ObjectId
    for (const id of userIds) {
      if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ message: 'ID nguoi dung khong hop le' });
      }
    }

    // Khong chia se cho nguoi tao
    const creatorIdStr = (task.createdBy._id || task.createdBy).toString();
    if (userIds.some((uid) => uid.toString() === creatorIdStr)) {
      return res.status(400).json({ message: 'Khong the chia se cong viec cho chinh nguoi tao' });
    }

    // Kiem tra tat ca user ton tai
    const uniqueInputIds = [...new Set(userIds.map((id) => id.toString()))];
    const foundUsers = await User.find({ _id: { $in: uniqueInputIds } });
    if (foundUsers.length !== uniqueInputIds.length) {
      return res.status(400).json({ message: 'Mot hoac nhieu nguoi dung khong ton tai' });
    }

    // Lay cac ban ghi chia se hien tai cua cong viec nay
    const existingShares = await TaskShare.find({
      taskId: task._id,
      userId: { $in: uniqueInputIds }
    });
    const existingUserIdSet = new Set(existingShares.map((s) => s.userId.toString()));

    const created = [];
    const skipped = [];

    for (const uid of uniqueInputIds) {
      if (existingUserIdSet.has(uid)) {
        skipped.push({ userId: uid, reason: 'Nguoi dung da duoc chia se cong viec nay' });
      } else {
        try {
          const newShare = await TaskShare.create({
            taskId: task._id,
            userId: uid,
            permission,
            sharedBy: req.user._id
          });

          const populated = await TaskShare.findById(newShare._id)
            .populate('userId', 'fullName email avatarUrl')
            .populate('sharedBy', 'fullName email avatarUrl');

          created.push({
            id: populated._id.toString(),
            user: {
              id: populated.userId._id.toString(),
              fullName: populated.userId.fullName,
              email: populated.userId.email,
              avatarUrl: populated.userId.avatarUrl
            },
            permission: populated.permission,
            sharedBy: {
              id: populated.sharedBy._id.toString(),
              fullName: populated.sharedBy.fullName,
              email: populated.sharedBy.email
            },
            createdAt: populated.createdAt
          });
        } catch (err) {
          if (err.code === 11000) {
            skipped.push({ userId: uid, reason: 'Nguoi dung da duoc chia se cong viec nay' });
          } else {
            throw err;
          }
        }
      }
    }

    // Thong bao cho nhung nguoi vua duoc chia se (bo qua ban ghi da ton tai)
    const createdUserIdSet = new Set(created.map((item) => item.user.id));
    const newlySharedUsers = foundUsers.filter((user) =>
      createdUserIdSet.has(user._id.toString())
    );

    if (newlySharedUsers.length > 0) {
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'shared',
        details: {
          userIds: newlySharedUsers.map((user) => user._id.toString()),
          permission
        }
      });

      await notifyTaskShared({
        task,
        actor: req.user,
        recipients: newlySharedUsers,
        permission
      });

      // Gui email moi chia se (loi email khong lam hong viec chia se)
      await sendTaskSharedEmails({
        task,
        actor: req.user,
        recipients: newlySharedUsers,
        permission
      });
    }

    return res.status(201).json({
      message: 'Chia se cong viec thanh cong',
      created,
      skipped
    });
  } catch (error) {
    next(error);
  }
};

// PATCH /api/tasks/:id/shares/:shareId (cap nhat quyen)
const updateShare = async (req, res, next) => {
  try {
    const task = req.task;
    const { shareId } = req.params;
    const { permission } = req.body;

    const allowedPermissions = ['viewer', 'editor'];
    if (!permission || !allowedPermissions.includes(permission)) {
      return res.status(400).json({ message: 'Quyen chia se phai la viewer hoac editor' });
    }

    if (!mongoose.Types.ObjectId.isValid(shareId)) {
      return res.status(400).json({ message: 'ID ban ghi chia se khong hop le' });
    }

    // Ban ghi phai thuoc cong viec nay (404)
    const share = await TaskShare.findOne({ _id: shareId, taskId: task._id });
    if (!share) {
      return res.status(404).json({ message: 'Khong tim thay ban ghi chia se' });
    }

    share.permission = permission;
    await share.save();

    await logActivity({
      taskId: task._id,
      userId: req.user._id,
      action: 'share_updated',
      details: {
        shareId: share._id.toString(),
        userId: share.userId.toString(),
        permission
      }
    });

    const populated = await TaskShare.findById(share._id)
      .populate('userId', 'fullName email avatarUrl')
      .populate('sharedBy', 'fullName email avatarUrl');

    return res.status(200).json({
      message: 'Cap nhat quyen chia se thanh cong',
      share: {
        id: populated._id.toString(),
        user: populated.userId
          ? {
              id: populated.userId._id.toString(),
              fullName: populated.userId.fullName,
              email: populated.userId.email,
              avatarUrl: populated.userId.avatarUrl
            }
          : null,
        permission: populated.permission,
        sharedBy: populated.sharedBy
          ? {
              id: populated.sharedBy._id.toString(),
              fullName: populated.sharedBy.fullName,
              email: populated.sharedBy.email
            }
          : null,
        createdAt: populated.createdAt
      }
    });
  } catch (error) {
    next(error);
  }
};

// DELETE /api/tasks/:id/shares/:shareId (thu hoi quyen)
const deleteShare = async (req, res, next) => {
  try {
    const task = req.task;
    const { shareId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(shareId)) {
      return res.status(400).json({ message: 'ID ban ghi chia se khong hop le' });
    }

    // Ban ghi phai thuoc cong viec nay (404)
    const share = await TaskShare.findOne({ _id: shareId, taskId: task._id });
    if (!share) {
      return res.status(404).json({ message: 'Khong tim thay ban ghi chia se' });
    }

    await TaskShare.findByIdAndDelete(share._id);

    await logActivity({
      taskId: task._id,
      userId: req.user._id,
      action: 'share_revoked',
      details: {
        shareId: share._id.toString(),
        userId: share.userId.toString(),
        permission: share.permission
      }
    });

    return res.status(200).json({
      message: 'Thu hoi quyen chia se thanh cong'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getShares,
  createShares,
  updateShare,
  deleteShare
};
