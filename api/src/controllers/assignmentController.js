const mongoose = require('mongoose');
const Task = require('../models/Task');
const User = require('../models/User');
const { formatTaskDetail } = require('./taskController');
const { notifyTaskAssigned } = require('../services/notificationService');

// GET /api/tasks/:id/assignees (quyen xem)
const getAssignees = async (req, res, next) => {
  try {
    const task = await Task.findById(req.task._id)
      .populate('assigneeIds', 'fullName email avatarUrl')
      .populate('primaryAssigneeId', 'fullName email avatarUrl');

    const primaryIdStr = task.primaryAssigneeId
      ? (task.primaryAssigneeId._id || task.primaryAssigneeId).toString()
      : null;

    const assignees = (task.assigneeIds || []).map((user) => ({
      user: {
        id: user._id.toString(),
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl
      },
      isPrimary: primaryIdStr === user._id.toString()
    }));

    return res.status(200).json({
      message: 'Lay danh sach nguoi duoc giao thanh cong',
      assignees
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/tasks/:id/assignees (quyen giao viec)
const assignUsers = async (req, res, next) => {
  try {
    const task = req.task;
    const { userIds, primaryAssigneeId } = req.body;

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'Danh sach userIds khong duoc de trong' });
    }

    // Kiem tra tinh hop le cua cac ID
    for (const id of userIds) {
      if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ message: 'ID nguoi dung khong hop le' });
      }
    }

    if (primaryAssigneeId && !mongoose.Types.ObjectId.isValid(primaryAssigneeId)) {
      return res.status(400).json({ message: 'ID nguoi phu trach chinh khong hop le' });
    }

    // Kiem tra tat ca user co ton tai trong co so du lieu khong (tu choi ca yeu cau neu co nguoi khong ton tai)
    const uniqueInputIds = [...new Set(userIds.map((id) => id.toString()))];
    const foundUsers = await User.find({ _id: { $in: uniqueInputIds } });

    if (foundUsers.length !== uniqueInputIds.length) {
      return res.status(400).json({ message: 'Mot hoac nhieu nguoi dung khong ton tai' });
    }

    // Gop vao assigneeIds khong trung
    const existingSet = new Set((task.assigneeIds || []).map((id) => id.toString()));
    const newlyAssignedUsers = foundUsers.filter(
      (user) => !existingSet.has(user._id.toString())
    );

    for (const uid of uniqueInputIds) {
      existingSet.add(uid);
    }
    task.assigneeIds = Array.from(existingSet);

    // Xu ly primaryAssigneeId
    if (primaryAssigneeId) {
      if (!existingSet.has(primaryAssigneeId.toString())) {
        return res.status(400).json({ message: 'Nguoi phu trach chinh phai nam trong danh sach duoc giao' });
      }
      task.primaryAssigneeId = primaryAssigneeId;
    } else if (!task.primaryAssigneeId && uniqueInputIds.length > 0) {
      // Neu cong viec chua co nguoi phu trach chinh va khong gui thi nguoi dau tien moi thanh chinh
      task.primaryAssigneeId = uniqueInputIds[0];
    }

    await task.save();

    // Tao thong bao trong ung dung cho nhung nguoi moi duoc giao
    await notifyTaskAssigned({
      task,
      actor: req.user,
      recipients: newlyAssignedUsers
    });

    const formatted = await formatTaskDetail(task, req.taskPermissions);
    return res.status(200).json({
      message: 'Giao viec thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

// PATCH /api/tasks/:id/assignees/:userId (dat nguoi phu trach chinh)
const setPrimaryAssignee = async (req, res, next) => {
  try {
    const task = req.task;
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'ID nguoi dung khong hop le' });
    }

    const isAssigned = (task.assigneeIds || []).some(
      (id) => id.toString() === userId.toString()
    );

    if (!isAssigned) {
      return res.status(404).json({ message: 'Nguoi dung khong co trong danh sach duoc giao' });
    }

    task.primaryAssigneeId = userId;
    await task.save();

    const formatted = await formatTaskDetail(task, req.taskPermissions);
    return res.status(200).json({
      message: 'Dat nguoi phu trach chinh thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

// DELETE /api/tasks/:id/assignees/:userId (huy giao viec)
const removeAssignee = async (req, res, next) => {
  try {
    const task = req.task;
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'ID nguoi dung khong hop le' });
    }

    const isAssigned = (task.assigneeIds || []).some(
      (id) => id.toString() === userId.toString()
    );

    if (!isAssigned) {
      return res.status(404).json({ message: 'Nguoi dung khong co trong danh sach duoc giao' });
    }

    task.assigneeIds = task.assigneeIds.filter(
      (id) => id.toString() !== userId.toString()
    );

    // Neu la nguoi phu trach chinh thi primaryAssigneeId = null
    if (task.primaryAssigneeId && task.primaryAssigneeId.toString() === userId.toString()) {
      task.primaryAssigneeId = null;
    }

    await task.save();

    const formatted = await formatTaskDetail(task, req.taskPermissions);
    return res.status(200).json({
      message: 'Huy giao viec thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAssignees,
  assignUsers,
  setPrimaryAssignee,
  removeAssignee
};
