const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const { getTaskPermissions } = require('../services/taskService');
const {
  notifyTaskStatusChanged,
  notifyTaskDueDateChanged
} = require('../services/notificationService');

// Helper dinh dang chi tiet mot cong viec tra ve client (kem permissions)
const formatTaskDetail = async (taskDoc, permissions) => {
  const taskId = taskDoc._id;

  const populatedTask = await Task.findById(taskId)
    .populate('createdBy', 'fullName email avatarUrl')
    .populate('primaryAssigneeId', 'fullName email avatarUrl')
    .populate('assigneeIds', 'fullName email avatarUrl');

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
    sharedBy: s.sharedBy
      ? {
          id: s.sharedBy._id.toString(),
          fullName: s.sharedBy.fullName,
          email: s.sharedBy.email,
          avatarUrl: s.sharedBy.avatarUrl
        }
      : null,
    createdAt: s.createdAt
  }));

  const taskObj = populatedTask.toObject();

  return {
    id: taskObj._id.toString(),
    title: taskObj.title,
    description: taskObj.description,
    status: taskObj.status,
    priority: taskObj.priority,
    startDate: taskObj.startDate,
    dueDate: taskObj.dueDate,
    createdBy: populatedTask.createdBy
      ? {
          id: populatedTask.createdBy._id.toString(),
          fullName: populatedTask.createdBy.fullName,
          email: populatedTask.createdBy.email,
          avatarUrl: populatedTask.createdBy.avatarUrl
        }
      : null,
    primaryAssignee: populatedTask.primaryAssigneeId
      ? {
          id: populatedTask.primaryAssigneeId._id.toString(),
          fullName: populatedTask.primaryAssigneeId.fullName,
          email: populatedTask.primaryAssigneeId.email,
          avatarUrl: populatedTask.primaryAssigneeId.avatarUrl
        }
      : null,
    assignees: (populatedTask.assigneeIds || []).map((a) => ({
      id: a._id.toString(),
      fullName: a.fullName,
      email: a.email,
      avatarUrl: a.avatarUrl
    })),
    shares: formattedShares,
    userRole: permissions.userRole,
    permissions: {
      canEdit: permissions.canEdit,
      canChangeStatus: permissions.canChangeStatus,
      canDelete: permissions.canDelete,
      canAssign: permissions.canAssign,
      canShare: permissions.canShare
    },
    createdAt: taskObj.createdAt,
    updatedAt: taskObj.updatedAt
  };
};

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

    // Gan userRole va permissions cho moi task
    const tasksWithRole = tasks.map((task) => {
      const taskObj = task.toObject();
      const share = sharePermissionMap.has(task._id.toString())
        ? { permission: sharePermissionMap.get(task._id.toString()) }
        : null;
      const perms = getTaskPermissions(task, userId, share);

      return {
        ...taskObj,
        id: taskObj._id.toString(),
        userRole: perms.userRole,
        permissions: {
          canEdit: perms.canEdit,
          canChangeStatus: perms.canChangeStatus,
          canDelete: perms.canDelete,
          canAssign: perms.canAssign,
          canShare: perms.canShare
        }
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

// GET /api/tasks/:id (dung requireTaskPermission('view'))
const getTaskById = async (req, res, next) => {
  try {
    const formatted = await formatTaskDetail(req.task, req.taskPermissions);
    return res.status(200).json({
      message: 'Lay thong tin chi tiet cong viec thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/tasks
const createTask = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const { title, description, priority, status, startDate, dueDate } = req.validatedBody;

    const task = new Task({
      title,
      description,
      priority,
      status,
      startDate,
      dueDate,
      createdBy: userId,
      assigneeIds: [],
      primaryAssigneeId: null
    });

    await task.save();

    const permissions = getTaskPermissions(task, userId, null);
    const formatted = await formatTaskDetail(task, permissions);

    return res.status(201).json({
      message: 'Tao cong viec thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

// PUT /api/tasks/:id (dung requireTaskPermission('edit'))
const updateTask = async (req, res, next) => {
  try {
    const task = req.task;
    const { title, description, priority, status, startDate, dueDate } = req.validatedBody;

    const oldStatus = task.status;
    const oldDueTime = task.dueDate ? task.dueDate.getTime() : null;

    task.title = title;
    task.description = description;
    task.priority = priority;
    task.status = status;
    task.startDate = startDate;
    task.dueDate = dueDate;

    await task.save();

    // Thong bao cho nguoi tao va nguoi duoc giao khi thong tin quan trong thay doi
    const recipients = [task.createdBy, ...(task.assigneeIds || [])];

    if (oldStatus !== task.status) {
      await notifyTaskStatusChanged({
        task,
        actor: req.user,
        recipients,
        fromStatus: oldStatus,
        toStatus: task.status
      });
    }

    const newDueTime = task.dueDate ? task.dueDate.getTime() : null;
    if (oldDueTime !== newDueTime) {
      await notifyTaskDueDateChanged({
        task,
        actor: req.user,
        recipients,
        oldDueDate: oldDueTime
      });
    }

    const formatted = await formatTaskDetail(task, req.taskPermissions);
    return res.status(200).json({
      message: 'Cap nhat cong viec thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

// PATCH /api/tasks/:id/status (dung requireTaskPermission('changeStatus'))
const updateTaskStatus = async (req, res, next) => {
  try {
    const task = req.task;
    const { status } = req.validatedBody;
    const oldStatus = task.status;

    task.status = status;
    await task.save();

    if (oldStatus !== task.status) {
      await notifyTaskStatusChanged({
        task,
        actor: req.user,
        recipients: [task.createdBy, ...(task.assigneeIds || [])],
        fromStatus: oldStatus,
        toStatus: task.status
      });
    }

    const formatted = await formatTaskDetail(task, req.taskPermissions);
    return res.status(200).json({
      message: 'Cap nhat trang thai thanh cong',
      task: formatted
    });
  } catch (error) {
    next(error);
  }
};

// DELETE /api/tasks/:id (dung requireTaskPermission('delete'))
const deleteTask = async (req, res, next) => {
  try {
    const task = req.task;

    // Xoa tat ca task_shares cua cong viec nay
    await TaskShare.deleteMany({ taskId: task._id });

    // Xoa cong viec
    await Task.findByIdAndDelete(task._id);

    return res.status(200).json({
      message: 'Xoa cong viec thanh cong'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTasks,
  getTaskById,
  createTask,
  updateTask,
  updateTaskStatus,
  deleteTask,
  formatTaskDetail
};
