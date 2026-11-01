const mongoose = require('mongoose');
const Notification = require('../models/Notification');

const STATUS_LABELS = {
  todo: 'Chua thuc hien',
  in_progress: 'Dang thuc hien',
  completed: 'Da hoan thanh'
};

const toIdString = (value) => {
  if (!value) return null;
  return (value._id || value).toString();
};

// Loai bo nguoi thao tac va nguoi trung lap khoi danh sach nhan thong bao
const normalizeRecipients = (recipients = [], actorId = null) => {
  const actorIdStr = toIdString(actorId);
  const seen = new Set();
  const result = [];

  for (const recipient of recipients) {
    if (!recipient) continue;
    const id = toIdString(recipient);
    if (!id || id === actorIdStr || seen.has(id)) continue;
    seen.add(id);
    result.push(id);
  }

  return result;
};

/**
 * Tao nhieu thong bao cung luc, bo qua nguoi thao tac va nguoi trung lap.
 * Loi tao thong bao khong duoc lam hong nghiep vu chinh.
 */
const notifyUsers = async ({
  recipients = [],
  actorId = null,
  taskId = null,
  type,
  title,
  message
}) => {
  try {
    const userIds = normalizeRecipients(recipients, actorId);
    if (userIds.length === 0) return [];

    const docs = userIds.map((userId) => ({
      userId: new mongoose.Types.ObjectId(userId),
      taskId: taskId ? new mongoose.Types.ObjectId(taskId) : null,
      type,
      title,
      message,
      isRead: false
    }));

    return await Notification.insertMany(docs);
  } catch (error) {
    console.error('Loi tao thong bao trong ung dung:', error.message);
    return [];
  }
};

const notifyTaskAssigned = async ({ task, actor, recipients }) => {
  return notifyUsers({
    recipients,
    actorId: actor,
    taskId: task._id,
    type: 'task_assigned',
    title: 'Ban duoc giao cong viec moi',
    message: `${actor.fullName} da giao cho ban cong viec "${task.title}".`
  });
};

const notifyTaskShared = async ({ task, actor, recipients, permission }) => {
  const permissionLabel = permission === 'editor' ? 'chinh sua' : 'chi xem';
  return notifyUsers({
    recipients,
    actorId: actor,
    taskId: task._id,
    type: 'task_shared',
    title: 'Ban duoc chia se cong viec',
    message: `${actor.fullName} da chia se cong viec "${task.title}" cho ban voi quyen ${permissionLabel}.`
  });
};

const notifyTaskStatusChanged = async ({
  task,
  actor,
  recipients,
  fromStatus,
  toStatus
}) => {
  const isCompleted = toStatus === 'completed';
  const fromLabel = STATUS_LABELS[fromStatus] || fromStatus;
  const toLabel = STATUS_LABELS[toStatus] || toStatus;

  return notifyUsers({
    recipients,
    actorId: actor,
    taskId: task._id,
    type: isCompleted ? 'task_completed' : 'task_status_changed',
    title: isCompleted ? 'Cong viec da hoan thanh' : 'Trang thai cong viec thay doi',
    message: isCompleted
      ? `${actor.fullName} da danh dau cong viec "${task.title}" la da hoan thanh.`
      : `${actor.fullName} da doi trang thai cong viec "${task.title}" tu "${fromLabel}" sang "${toLabel}".`
  });
};

const notifyTaskDueDateChanged = async ({
  task,
  actor,
  recipients,
  oldDueDate
}) => {
  const oldLabel = oldDueDate ? new Date(oldDueDate).toLocaleString('vi-VN') : 'chua thiet lap';
  const newLabel = task.dueDate ? new Date(task.dueDate).toLocaleString('vi-VN') : 'chua thiet lap';

  return notifyUsers({
    recipients,
    actorId: actor,
    taskId: task._id,
    type: 'task_due_changed',
    title: 'Han hoan thanh cong viec thay doi',
    message: `${actor.fullName} da doi han hoan thanh cong viec "${task.title}" tu ${oldLabel} sang ${newLabel}.`
  });
};

module.exports = {
  notifyUsers,
  notifyTaskAssigned,
  notifyTaskShared,
  notifyTaskStatusChanged,
  notifyTaskDueDateChanged,
  normalizeRecipients,
  STATUS_LABELS
};
