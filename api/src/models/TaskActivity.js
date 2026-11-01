const mongoose = require('mongoose');

const taskActivitySchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: [true, 'Ma cong viec la bat buoc']
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Nguoi thuc hien la bat buoc']
    },
    action: {
      type: String,
      required: [true, 'Hanh dong la bat buoc'],
      enum: [
        'created',
        'updated',
        'status_changed',
        'assigned',
        'unassigned',
        'primary_changed',
        'shared',
        'share_updated',
        'share_revoked'
      ]
    },
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: {}
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

taskActivitySchema.index({ taskId: 1, createdAt: -1 });

const TaskActivity = mongoose.model('TaskActivity', taskActivitySchema);

module.exports = TaskActivity;
