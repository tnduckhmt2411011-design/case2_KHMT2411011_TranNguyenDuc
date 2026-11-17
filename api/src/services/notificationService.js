const mongoose = require('mongoose');
const Notification = require('../models/Notification');

const STATUS_LABELS = {
  todo: 'Chưa thực hiện',
  in_progress: 'Đang thực hiện',
  completed: 'Đã hoàn thành'
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
    title: 'Bạn được giao công việc mới',
    message: `${actor.fullName} đã giao cho bạn công việc "${task.title}".`
  });
};

const notifyTaskShared = async ({ task, actor, recipients, permission }) => {
  const permissionLabel = permission === 'editor' ? 'chỉnh sửa' : 'chỉ xem';
  return notifyUsers({
    recipients,
    actorId: actor,
    taskId: task._id,
    type: 'task_shared',
    title: 'Bạn được chia sẻ công việc',
    message: `${actor.fullName} đã chia sẻ công việc "${task.title}" cho bạn với quyền ${permissionLabel}.`
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
    title: isCompleted ? 'Công việc đã hoàn thành' : 'Trạng thái công việc thay đổi',
    message: isCompleted
      ? `${actor.fullName} đã đánh dấu công việc "${task.title}" là đã hoàn thành.`
      : `${actor.fullName} đã đổi trạng thái công việc "${task.title}" từ "${fromLabel}" sang "${toLabel}".`
  });
};

const notifyTaskDueDateChanged = async ({
  task,
  actor,
  recipients,
  oldDueDate
}) => {
  const oldLabel = oldDueDate ? new Date(oldDueDate).toLocaleString('vi-VN') : 'chưa thiết lập';
  const newLabel = task.dueDate ? new Date(task.dueDate).toLocaleString('vi-VN') : 'chưa thiết lập';

  return notifyUsers({
    recipients,
    actorId: actor,
    taskId: task._id,
    type: 'task_due_changed',
    title: 'Hạn hoàn thành công việc thay đổi',
    message: `${actor.fullName} đã đổi hạn hoàn thành công việc "${task.title}" từ ${oldLabel} sang ${newLabel}.`
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
