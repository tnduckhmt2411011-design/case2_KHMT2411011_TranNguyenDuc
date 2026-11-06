const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');

/**
 * Tinh toan quyen han thuc te cua nguoi dung doi voi mot cong viec
 * Quy tac: Quyen hieu luc la HOP cac vai tro nguoi do dang co
 * @param {object} task 
 * @param {string|mongoose.Types.ObjectId} userId 
 * @param {object|null} share 
 * @returns {{ canView: boolean, canEdit: boolean, canChangeStatus: boolean, canDelete: boolean, canAssign: boolean, canShare: boolean, userRole: string|null }}
 */
const getTaskPermissions = (task, userId, share = null) => {
  if (!task || !userId) {
    return {
      canView: false,
      canEdit: false,
      canChangeStatus: false,
      canDelete: false,
      canAssign: false,
      canShare: false,
      canViewEmailLogs: false,
      userRole: null
    };
  }

  const userIdStr = (userId._id || userId).toString();

  // 1. Kiem tra xem co phai nguoi tao (creator) khong
  const createdByIdStr = task.createdBy
    ? (task.createdBy._id || task.createdBy).toString()
    : null;
  const isCreator = Boolean(createdByIdStr && createdByIdStr === userIdStr);

  // 2. Kiem tra xem co phai nguoi duoc giao (assignee) khong
  const primaryIdStr = task.primaryAssigneeId
    ? (task.primaryAssigneeId._id || task.primaryAssigneeId).toString()
    : null;
  const isPrimary = Boolean(primaryIdStr && primaryIdStr === userIdStr);

  const isAssigneeList = Array.isArray(task.assigneeIds) && task.assigneeIds.some((id) => {
    const idStr = (id._id || id).toString();
    return idStr === userIdStr;
  });

  const isAssignee = Boolean(isPrimary || isAssigneeList);

  // 3. Kiem tra quyen duoc chia se (share)
  const sharePermission = share ? share.permission : null; // 'viewer' | 'editor'
  const isEditor = sharePermission === 'editor';
  const isViewer = sharePermission === 'viewer';

  // Tinh hop cac quyen theo Ma tran quyen (DE muc 9)
  const canView = Boolean(isCreator || isEditor || isAssignee || isViewer);
  const canEdit = Boolean(isCreator || isEditor);
  const canChangeStatus = Boolean(isCreator || isEditor || isAssignee);
  const canDelete = Boolean(isCreator);
  const canAssign = Boolean(isCreator);
  const canShare = Boolean(isCreator);
  const canViewEmailLogs = Boolean(isCreator);

  // Xac dinh nhan userRole uu tien cho giao dien
  let userRole = null;
  if (isCreator) {
    userRole = 'creator';
  } else if (isEditor) {
    userRole = 'editor';
  } else if (isAssignee) {
    userRole = 'assignee';
  } else if (isViewer) {
    userRole = 'viewer';
  }

  return {
    canView,
    canEdit,
    canChangeStatus,
    canDelete,
    canAssign,
    canShare,
    canViewEmailLogs,
    userRole
  };
};

/**
 * Kiem tra quyen truy cap cua nguoi dung doi voi mot cong viec (tuong thich nguoc)
 * @param {string|mongoose.Types.ObjectId} taskId 
 * @param {string|mongoose.Types.ObjectId} userId 
 * @returns {Promise<{ hasAccess: boolean, role: string|null, task: object|null, notFound?: boolean, invalidId?: boolean, permissions: object }>}
 */
const checkTaskAccess = async (taskId, userId) => {
  if (!mongoose.Types.ObjectId.isValid(taskId)) {
    return { invalidId: true, hasAccess: false, role: null, task: null };
  }

  const task = await Task.findById(taskId);
  if (!task) {
    return { notFound: true, hasAccess: false, role: null, task: null };
  }

  const share = await TaskShare.findOne({
    taskId: task._id,
    userId: new mongoose.Types.ObjectId(userId)
  });

  const permissions = getTaskPermissions(task, userId, share);

  return {
    hasAccess: permissions.canView,
    role: permissions.userRole,
    task,
    permissions
  };
};

/**
 * Ghi lich su hoat dong cua cong viec.
 * Loi ghi log khong duoc lam hong nghiep vu chinh.
 */
const logActivity = async ({ taskId, userId, action, details = {} }) => {
  try {
    if (!taskId || !userId || !action) return null;
    return await TaskActivity.create({
      taskId,
      userId,
      action,
      details
    });
  } catch (error) {
    console.error('Loi ghi lich su hoat dong:', error.message);
    return null;
  }
};

module.exports = {
  getTaskPermissions,
  checkTaskAccess,
  logActivity
};
