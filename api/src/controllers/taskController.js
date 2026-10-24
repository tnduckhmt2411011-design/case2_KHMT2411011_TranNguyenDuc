const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const { checkTaskAccess } = require('../services/taskService');

// GET /api/tasks?scope=created|assigned|shared
const getTasks = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const { scope } = req.query;

    let filter = {};

    // Tim cac taskId duoc chia se voi nguoi dung nay
    const userShares = await TaskShare.find({ userId }).select('taskId permission');
    const sharedTaskIds = userShares.map((s) => s.taskId);
    const sharePermissionMap = new Map();
    userShares.forEach((s) => sharePermissionMap.set(s.taskId.toString(), s.permission));

    if (scope === 'created') {
      filter = { createdBy: userId };
    } else if (scope === 'assigned') {
      filter = {
        $or: [{ primaryAssigneeId: userId }, { assigneeIds: userId }]
      };
    } else if (scope === 'shared') {
      filter = { _id: { $in: sharedTaskIds } };
    } else {
      // Mac dinh: tat ca cong viec nguoi dung co quyen truy cap
      filter = {
        $or: [
          { createdBy: userId },
          { primaryAssigneeId: userId },
          { assigneeIds: userId },
          { _id: { $in: sharedTaskIds } }
        ]
      };
    }

    const tasks = await Task.find(filter)
      .populate('createdBy', 'fullName email avatarUrl')
      .populate('primaryAssigneeId', 'fullName email avatarUrl')
      .populate('assigneeIds', 'fullName email avatarUrl')
      .sort({ createdAt: -1 });

    // Gan userRole cho moi task de phia frontend de dang hien thi
    const tasksWithRole = tasks.map((task) => {
      const taskObj = task.toObject();
      let userRole = 'viewer';

      if (task.createdBy && task.createdBy._id.equals(userId)) {
        userRole = 'creator';
      } else if (
        (task.primaryAssigneeId && task.primaryAssigneeId._id.equals(userId)) ||
        (task.assigneeIds && task.assigneeIds.some((a) => a._id.equals(userId)))
      ) {
        userRole = 'assignee';
      } else if (sharePermissionMap.has(task._id.toString())) {
        userRole = sharePermissionMap.get(task._id.toString());
      }

      return {
        ...taskObj,
        id: taskObj._id.toString(),
        userRole
      };
    });

    return res.status(200).json({
      message: 'Lay danh sach cong viec thanh cong',
      tasks: tasksWithRole
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/tasks/:id
const getTaskById = async (req, res, next) => {
  try {
    const taskId = req.params.id;
    const userId = req.user._id;

    if (!mongoose.Types.ObjectId.isValid(taskId)) {
      return res.status(400).json({ message: 'ID cong viec khong hop le' });
    }

    const taskCheck = await checkTaskAccess(taskId, userId);
    if (taskCheck.invalidId) {
      return res.status(400).json({ message: 'ID cong viec khong hop le' });
    }
    if (taskCheck.notFound) {
      return res.status(404).json({ message: 'Khong tim thay cong viec' });
    }
    if (!taskCheck.hasAccess) {
      return res.status(403).json({ message: 'Ban khong co quyen truy cap cong viec nay' });
    }

    // Populate task details (tuyet doi khong co passwordHash)
    const task = await Task.findById(taskId)
      .populate('createdBy', 'fullName email avatarUrl')
      .populate('primaryAssigneeId', 'fullName email avatarUrl')
      .populate('assigneeIds', 'fullName email avatarUrl');

    // Lay danh sach nguoi duoc chia se
    const shares = await TaskShare.find({ taskId })
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
      createdAt: s.createdAt
    }));

    const taskObj = task.toObject();

    return res.status(200).json({
      message: 'Lay thong tin chi tiet cong viec thanh cong',
      task: {
        id: taskObj._id.toString(),
        title: taskObj.title,
        description: taskObj.description,
        status: taskObj.status,
        priority: taskObj.priority,
        startDate: taskObj.startDate,
        dueDate: taskObj.dueDate,
        createdBy: task.createdBy
          ? {
              id: task.createdBy._id.toString(),
              fullName: task.createdBy.fullName,
              email: task.createdBy.email,
              avatarUrl: task.createdBy.avatarUrl
            }
          : null,
        primaryAssignee: task.primaryAssigneeId
          ? {
              id: task.primaryAssigneeId._id.toString(),
              fullName: task.primaryAssigneeId.fullName,
              email: task.primaryAssigneeId.email,
              avatarUrl: task.primaryAssigneeId.avatarUrl
            }
          : null,
        assignees: (task.assigneeIds || []).map((a) => ({
          id: a._id.toString(),
          fullName: a.fullName,
          email: a.email,
          avatarUrl: a.avatarUrl
        })),
        shares: formattedShares,
        userRole: taskCheck.role,
        createdAt: taskObj.createdAt,
        updatedAt: taskObj.updatedAt
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTasks,
  getTaskById
};
