const mongoose = require('mongoose');
const Notification = require('../models/Notification');

const formatNotification = (notification) => {
  const task = notification.taskId && notification.taskId._id
    ? {
        id: notification.taskId._id.toString(),
        title: notification.taskId.title
      }
    : null;

  return {
    id: notification._id.toString(),
    userId: notification.userId
      ? (notification.userId._id || notification.userId).toString()
      : null,
    taskId: task ? task.id : null,
    task,
    type: notification.type,
    title: notification.title,
    message: notification.message,
    isRead: notification.isRead,
    createdAt: notification.createdAt
  };
};

// GET /api/notifications?unread=true
const getNotifications = async (req, res, next) => {
  try {
    const filter = { userId: req.user._id };
    if (req.query.unread === 'true' || req.query.unread === '1') {
      filter.isRead = false;
    }

    const notifications = await Notification.find(filter)
      .populate('taskId', 'title')
      .sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lay danh sach thong bao thanh cong',
      notifications: notifications.map(formatNotification)
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/notifications/unread-count
const getUnreadCount = async (req, res, next) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user._id,
      isRead: false
    });

    return res.status(200).json({
      message: 'Dem thong bao chua doc thanh cong',
      count
    });
  } catch (error) {
    next(error);
  }
};

// PATCH /api/notifications/:id/read
const markAsRead = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'ID thong bao khong hop le' });
    }

    const notification = await Notification.findOneAndUpdate(
      { _id: id, userId: req.user._id },
      { isRead: true },
      { new: true }
    ).populate('taskId', 'title');

    if (!notification) {
      return res.status(404).json({ message: 'Khong tim thay thong bao' });
    }

    return res.status(200).json({
      message: 'Da danh dau thong bao la da doc',
      notification: formatNotification(notification)
    });
  } catch (error) {
    next(error);
  }
};

// PATCH /api/notifications/read-all
const markAllAsRead = async (req, res, next) => {
  try {
    const result = await Notification.updateMany(
      { userId: req.user._id, isRead: false },
      { isRead: true }
    );

    return res.status(200).json({
      message: 'Da danh dau tat ca thong bao la da doc',
      modifiedCount: result.modifiedCount
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  formatNotification
};
