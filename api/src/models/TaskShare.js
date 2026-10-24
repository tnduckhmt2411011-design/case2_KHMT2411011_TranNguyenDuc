const mongoose = require('mongoose');

const taskShareSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: [true, 'Ma cong viec la bat buoc']
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Ma nguoi duoc chia se la bat buoc']
    },
    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      required: [true, 'Quyen truy cap (viewer hoac editor) la bat buoc']
    },
    sharedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Nguoi chia se la bat buoc']
    },
    createdAt: {
      type: Date,
      default: Date.now
    }
  }
);

// Unique compound index taskId + userId
taskShareSchema.index({ taskId: 1, userId: 1 }, { unique: true });

const TaskShare = mongoose.model('TaskShare', taskShareSchema);

module.exports = TaskShare;
