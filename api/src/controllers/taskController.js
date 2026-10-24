const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

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

module.exports = {
  getTasks
};
