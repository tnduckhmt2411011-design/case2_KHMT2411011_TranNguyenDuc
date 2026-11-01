const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      default: null
    },
    recipientEmail: {
      type: String,
      required: [true, 'Email nguoi nhan la bat buoc'],
      lowercase: true,
      trim: true
    },
    eventType: {
      type: String,
      required: [true, 'Loai su kien email la bat buoc'],
      enum: ['task_assigned', 'task_shared', 'task_due_changed', 'task_completed']
    },
    subject: {
      type: String,
      required: [true, 'Tieu de email la bat buoc'],
      trim: true
    },
    status: {
      type: String,
      enum: ['pending', 'sent', 'failed'],
      default: 'pending'
    },
    attempts: {
      type: Number,
      default: 0,
      min: 0
    },
    errorMessage: {
      type: String,
      default: ''
    },
    sentAt: {
      type: Date,
      default: null
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

emailLogSchema.index({ taskId: 1, createdAt: -1 });
emailLogSchema.index({ status: 1, createdAt: -1 });

const EmailLog = mongoose.model('EmailLog', emailLogSchema);

module.exports = EmailLog;
