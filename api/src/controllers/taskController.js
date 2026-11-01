const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');
const Notification = require('../models/Notification');
const EmailLog = require('../models/EmailLog');
const { getTaskPermissions, logActivity } = require('../services/taskService');
const {
  notifyTaskStatusChanged,
  notifyTaskDueDateChanged
} = require('../services/notificationService');
const {
  sendTaskDueChangedEmails,
  sendTaskCompletedEmails
} = require('../services/emailService');

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

const TASK_STATUSES = ['todo', 'in_progress', 'completed'];
const TASK_PRIORITIES = ['low', 'medium', 'high'];
const TASK_SORT_FIELDS = ['dueDate', 'priority', 'createdAt', 'updatedAt'];
const TASK_SORT_ORDERS = ['asc', 'desc'];
const PRIORITY_RANK = { low: 1, medium: 2, high: 3 };

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// So sanh task theo tieu chi sap xep, dua task khong co han xuong cuoi
const compareTasks = (a, b, sortBy, order) => {
  const direction = order === 'asc' ? 1 : -1;

  if (sortBy === 'priority') {
    const aRank = PRIORITY_RANK[a.priority] || 0;
    const bRank = PRIORITY_RANK[b.priority] || 0;
    if (aRank !== bRank) return (aRank - bRank) * direction;
    return (b.createdAt?.getTime() || 0) - (a.createdAt?.getTime() || 0);
  }

  if (sortBy === 'dueDate') {
    const aTime = a.dueDate ? new Date(a.dueDate).getTime() : null;
    const bTime = b.dueDate ? new Date(b.dueDate).getTime() : null;
    if (aTime === null && bTime === null) return 0;
    if (aTime === null) return 1;
    if (bTime === null) return -1;
    if (aTime !== bTime) return (aTime - bTime) * direction;
    return (b.createdAt?.getTime() || 0) - (a.createdAt?.getTime() || 0);
  }

  const aTime = a[sortBy] ? new Date(a[sortBy]).getTime() : 0;
  const bTime = b[sortBy] ? new Date(b[sortBy]).getTime() : 0;
  return (aTime - bTime) * direction;
};

// GET /api/tasks?scope=&q=&status=&priority=&assigneeId=&sortBy=&order=
const getTasks = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const {
      scope,
      q,
      status,
      priority,
      sortBy = 'createdAt',
      order
    } = req.query;
    const assigneeFilterId = req.query.assigneeId || req.query.assignee;

    // Kiem tra tham so loc/sap xep
    if (status !== undefined && !TASK_STATUSES.includes(status)) {
      return res.status(400).json({
        message: 'Trang thai loc khong hop le (todo, in_progress, completed)'
      });
    }

    if (priority !== undefined && !TASK_PRIORITIES.includes(priority)) {
      return res.status(400).json({
        message: 'Muc do uu tien loc khong hop le (low, medium, high)'
      });
    }

    if (!TASK_SORT_FIELDS.includes(sortBy)) {
      return res.status(400).json({
        message: 'Truong sap xep khong hop le (dueDate, priority, createdAt, updatedAt)'
      });
    }

    const effectiveOrder = order || ((sortBy === 'dueDate' || sortBy === 'priority') ? 'asc' : 'desc');
    if (!TASK_SORT_ORDERS.includes(effectiveOrder)) {
      return res.status(400).json({ message: 'Thu tu sap xep khong hop le (asc, desc)' });
    }

    if (assigneeFilterId !== undefined && !mongoose.Types.ObjectId.isValid(assigneeFilterId)) {
      return res.status(400).json({ message: 'ID nguoi phu trach khong hop le' });
    }

    // Tim cac taskId duoc chia se voi nguoi dung nay
    const userShares = await TaskShare.find({ userId }).select('taskId permission');
    const sharedTaskIds = userShares.map((s) => s.taskId);
    const sharePermissionMap = new Map();
    userShares.forEach((s) => sharePermissionMap.set(s.taskId.toString(), s.permission));

    const conditions = [];

    if (scope === 'created') {
      conditions.push({ createdBy: userId });
    } else if (scope === 'assigned') {
      conditions.push({
        $or: [{ primaryAssigneeId: userId }, { assigneeIds: userId }]
      });
    } else if (scope === 'shared') {
      conditions.push({ _id: { $in: sharedTaskIds } });
    } else {
      // Mac dinh: tat ca cong viec nguoi dung co quyen truy cap
      conditions.push({
        $or: [
          { createdBy: userId },
          { primaryAssigneeId: userId },
          { assigneeIds: userId },
          { _id: { $in: sharedTaskIds } }
        ]
      });
    }

    if (typeof q === 'string' && q.trim().length > 0) {
      conditions.push({ title: new RegExp(escapeRegex(q.trim()), 'i') });
    }

    if (status !== undefined) {
      conditions.push({ status });
    }

    if (priority !== undefined) {
      conditions.push({ priority });
    }

    if (assigneeFilterId !== undefined) {
      conditions.push({
        $or: [
          { primaryAssigneeId: assigneeFilterId },
          { assigneeIds: assigneeFilterId }
        ]
      });
    }

    const filter = conditions.length === 1 ? conditions[0] : { $and: conditions };

    const tasks = await Task.find(filter)
      .populate('createdBy', 'fullName email avatarUrl')
      .populate('primaryAssigneeId', 'fullName email avatarUrl')
      .populate('assigneeIds', 'fullName email avatarUrl');

    tasks.sort((a, b) => compareTasks(a, b, sortBy, effectiveOrder));

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
      filters: {
        scope: scope || 'all',
        q: typeof q === 'string' ? q.trim() : '',
        status: status || null,
        priority: priority || null,
        assigneeId: assigneeFilterId || null,
        sortBy,
        order: effectiveOrder
      },
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

    await logActivity({
      taskId: task._id,
      userId,
      action: 'created',
      details: { title: task.title }
    });

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
    const oldTitle = task.title;
    const oldDescription = task.description;
    const oldPriority = task.priority;
    const oldStartTime = task.startDate ? task.startDate.getTime() : null;

    task.title = title;
    task.description = description;
    task.priority = priority;
    task.status = status;
    task.startDate = startDate;
    task.dueDate = dueDate;

    await task.save();

    const newDueTime = task.dueDate ? task.dueDate.getTime() : null;
    const newStartTime = task.startDate ? task.startDate.getTime() : null;
    const changedFields = [];
    if (oldTitle !== task.title) changedFields.push('title');
    if (oldDescription !== task.description) changedFields.push('description');
    if (oldPriority !== task.priority) changedFields.push('priority');
    if (oldStatus !== task.status) changedFields.push('status');
    if (oldStartTime !== newStartTime) changedFields.push('startDate');
    if (oldDueTime !== newDueTime) changedFields.push('dueDate');

    await logActivity({
      taskId: task._id,
      userId: req.user._id,
      action: 'updated',
      details: { changedFields }
    });

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

      if (task.status === 'completed') {
        await sendTaskCompletedEmails({
          task,
          actor: req.user,
          recipients
        });
      }
    }

    if (oldDueTime !== newDueTime) {
      await notifyTaskDueDateChanged({
        task,
        actor: req.user,
        recipients,
        oldDueDate: oldDueTime
      });

      await sendTaskDueChangedEmails({
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
      await logActivity({
        taskId: task._id,
        userId: req.user._id,
        action: 'status_changed',
        details: { from: oldStatus, to: task.status }
      });

      const recipients = [task.createdBy, ...(task.assigneeIds || [])];

      await notifyTaskStatusChanged({
        task,
        actor: req.user,
        recipients,
        fromStatus: oldStatus,
        toStatus: task.status
      });

      if (task.status === 'completed') {
        await sendTaskCompletedEmails({
          task,
          actor: req.user,
          recipients
        });
      }
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

    // Xoa cac du lieu lien quan den cong viec
    await Promise.all([
      TaskShare.deleteMany({ taskId: task._id }),
      TaskActivity.deleteMany({ taskId: task._id }),
      Notification.deleteMany({ taskId: task._id }),
      EmailLog.deleteMany({ taskId: task._id })
    ]);

    // Xoa cong viec
    await Task.findByIdAndDelete(task._id);

    return res.status(200).json({
      message: 'Xoa cong viec thanh cong'
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/tasks/:id/activities (dung requireTaskPermission('view'))
const getTaskActivities = async (req, res, next) => {
  try {
    const activities = await TaskActivity.find({ taskId: req.task._id })
      .populate('userId', 'fullName email avatarUrl')
      .sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lay lich su hoat dong thanh cong',
      activities: activities.map((activity) => ({
        id: activity._id.toString(),
        taskId: activity.taskId.toString(),
        user: activity.userId
          ? {
              id: activity.userId._id.toString(),
              fullName: activity.userId.fullName,
              email: activity.userId.email,
              avatarUrl: activity.userId.avatarUrl
            }
          : null,
        action: activity.action,
        details: activity.details,
        createdAt: activity.createdAt
      }))
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
  getTaskActivities,
  formatTaskDetail
};
