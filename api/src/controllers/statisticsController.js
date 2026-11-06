const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

const STATUSES = ['todo', 'in_progress', 'completed'];
const PRIORITIES = ['low', 'medium', 'high'];
const UPCOMING_WINDOW_HOURS = 24;

const emptyStatusCount = () => ({ todo: 0, in_progress: 0, completed: 0 });
const emptyPriorityCount = () => ({ low: 0, medium: 0, high: 0 });

// Dieu kien lay tat ca cong viec nguoi dung co quyen truy cap
const buildAccessibleFilter = async (userId) => {
  const shares = await TaskShare.find({ userId }).select('taskId');
  const sharedTaskIds = shares.map((share) => share.taskId);

  return {
    $or: [
      { createdBy: userId },
      { primaryAssigneeId: userId },
      { assigneeIds: userId },
      { _id: { $in: sharedTaskIds } }
    ]
  };
};

const countByStatus = (tasks) => {
  const counts = emptyStatusCount();
  for (const task of tasks) {
    if (counts[task.status] !== undefined) counts[task.status] += 1;
  }
  return counts;
};

const countByPriority = (tasks) => {
  const counts = emptyPriorityCount();
  for (const task of tasks) {
    if (counts[task.priority] !== undefined) counts[task.priority] += 1;
  }
  return counts;
};

// GET /api/statistics/tasks
const getTaskStatistics = async (req, res, next) => {
  try {
    const filter = await buildAccessibleFilter(req.user._id);
    const tasks = await Task.find(filter).select('status priority');

    return res.status(200).json({
      message: 'Lay thong ke cong viec thanh cong',
      total: tasks.length,
      byStatus: countByStatus(tasks),
      byPriority: countByPriority(tasks)
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/statistics/assignments
const getAssignmentStatistics = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const userIdStr = userId.toString();

    const assignedTasks = await Task.find({
      $or: [{ primaryAssigneeId: userId }, { assigneeIds: userId }]
    }).select('status priority primaryAssigneeId');

    const primaryTasks = assignedTasks.filter((task) => {
      const primaryId = task.primaryAssigneeId
        ? (task.primaryAssigneeId._id || task.primaryAssigneeId).toString()
        : null;
      return primaryId === userIdStr;
    });

    return res.status(200).json({
      message: 'Lay thong ke giao viec thanh cong',
      totalAssigned: assignedTasks.length,
      totalPrimary: primaryTasks.length,
      assignedByStatus: countByStatus(assignedTasks),
      primaryByStatus: countByStatus(primaryTasks)
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/statistics/deadlines
const getDeadlineStatistics = async (req, res, next) => {
  try {
    let days = 3;
    if (req.query.days !== undefined) {
      const parsedDays = Number(req.query.days);
      if (!Number.isInteger(parsedDays) || parsedDays < 1 || parsedDays > 30) {
        return res.status(400).json({
          message: 'Tham so days phai la so nguyen tu 1 den 30'
        });
      }
      days = parsedDays;
    }

    const now = new Date();
    const upcomingLimit = new Date(
      now.getTime() + days * 24 * 60 * 60 * 1000
    );

    const accessibleFilter = await buildAccessibleFilter(req.user._id);
    const tasks = await Task.find({
      $and: [
        accessibleFilter,
        { status: { $ne: 'completed' }, dueDate: { $ne: null } }
      ]
    })
      .select('title status priority dueDate')
      .sort({ dueDate: 1 });

    const formatTask = (task) => ({
      id: task._id.toString(),
      title: task.title,
      status: task.status,
      priority: task.priority,
      dueDate: task.dueDate
    });

    const overdueAll = tasks
      .filter((task) => new Date(task.dueDate).getTime() < now.getTime())
      .map(formatTask);

    const upcomingAll = tasks
      .filter((task) => {
        const dueTime = new Date(task.dueDate).getTime();
        return dueTime >= now.getTime() && dueTime <= upcomingLimit.getTime();
      })
      .map(formatTask);

    return res.status(200).json({
      message: 'Lay thong ke han hoan thanh thanh cong',
      days,
      windowHours: days * 24,
      overdueCount: overdueAll.length,
      upcomingCount: upcomingAll.length,
      dueSoonCount: upcomingAll.length,
      overdue: overdueAll.slice(0, 10),
      upcoming: upcomingAll.slice(0, 10),
      dueSoon: upcomingAll.slice(0, 10)
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTaskStatistics,
  getAssignmentStatistics,
  getDeadlineStatistics,
  buildAccessibleFilter,
  UPCOMING_WINDOW_HOURS,
  STATUSES,
  PRIORITIES
};
