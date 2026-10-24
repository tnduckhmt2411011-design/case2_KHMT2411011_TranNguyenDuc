const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

/**
 * Kiem tra quyen truy cap cua nguoi dung doi voi mot cong viec
 * @param {string|mongoose.Types.ObjectId} taskId 
 * @param {string|mongoose.Types.ObjectId} userId 
 * @returns {Promise<{ hasAccess: boolean, role: string|null, task: object|null, notFound?: boolean, invalidId?: boolean }>}
 */
const checkTaskAccess = async (taskId, userId) => {
  if (!mongoose.Types.ObjectId.isValid(taskId)) {
    return { invalidId: true, hasAccess: false, role: null, task: null };
  }

  const task = await Task.findById(taskId);
  if (!task) {
    return { notFound: true, hasAccess: false, role: null, task: null };
  }

  const userObjectId = new mongoose.Types.ObjectId(userId);

  // 1. Nguoi tao cong viec
  if (task.createdBy.equals(userObjectId)) {
    return { hasAccess: true, role: 'creator', task };
  }

  // 2. Nguoi duoc giao (primaryAssigneeId hoac trong assigneeIds)
  const isPrimary = task.primaryAssigneeId && task.primaryAssigneeId.equals(userObjectId);
  const isAssignee = task.assigneeIds && task.assigneeIds.some((id) => id.equals(userObjectId));
  if (isPrimary || isAssignee) {
    return { hasAccess: true, role: 'assignee', task };
  }

  // 3. Nguoi duoc chia se trong TaskShare
  const share = await TaskShare.findOne({ taskId: task._id, userId: userObjectId });
  if (share) {
    return { hasAccess: true, role: share.permission, task };
  }

  // 4. Khong co quyen
  return { hasAccess: false, role: null, task };
};

module.exports = {
  checkTaskAccess
};
