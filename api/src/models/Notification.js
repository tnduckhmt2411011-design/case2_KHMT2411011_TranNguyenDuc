const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Nguoi nhan thong bao la bat buoc']
    },
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      default: null
    },
    type: {
      type: String,
      required: [true, 'Loai thong bao la bat buoc'],
      enum: [
        'task_assigned',
        'task_shared',
        'task_status_changed',
        'task_completed',
        'task_due_changed'
      ]
    },
    title: {
      type: String,
      required: [true, 'Tieu de thong bao la bat buoc'],
      trim: true
    },
    message: {
      type: String,
      required: [true, 'Noi dung thong bao la bat buoc'],
      trim: true
    },
    isRead: {
      type: Boolean,
      default: false
    },
    createdAt: {
      type: Date,
      default: Date.now
    }
  },
  {
    versionKey: false
  }
);

// Toi uu truy van danh sach thong bao cua mot nguoi dung
notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, isRead: 1 });

const Notification = mongoose.model('Notification', notificationSchema);

module.exports = Notification;
