const mongoose = require('mongoose');
const EmailLog = require('../models/EmailLog');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const { getTaskPermissions } = require('../services/taskService');
const { retryEmailLog, MAX_ATTEMPTS } = require('../services/emailService');

const formatEmailLog = (log) => {
  return {
    id: log._id.toString(),
    taskId: log.taskId ? (log.taskId._id || log.taskId).toString() : null,
    recipientEmail: log.recipientEmail,
    eventType: log.eventType,
    subject: log.subject,
    status: log.status,
    attempts: log.attempts,
    errorMessage: log.errorMessage,
    sentAt: log.sentAt,
    createdAt: log.createdAt
  };
};

// GET /api/tasks/:id/email-logs (quyen xem cong viec)
const getTaskEmailLogs = async (req, res, next) => {
  try {
    const logs = await EmailLog.find({ taskId: req.task._id }).sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lay lich su gui email thanh cong',
      emailLogs: logs.map(formatEmailLog)
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/email-logs/:id/retry (chi nguoi tao cong viec)
const retryEmailLogById = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'ID lich su email khong hop le' });
    }

    const log = await EmailLog.findById(id);
    if (!log) {
      return res.status(404).json({ message: 'Khong tim thay lich su gui email' });
    }

    if (!log.taskId) {
      return res.status(403).json({ message: 'Email nay khong gan voi cong viec nao' });
    }

    const task = await Task.findById(log.taskId);
    if (!task) {
      return res.status(404).json({ message: 'Khong tim thay cong viec cua email nay' });
    }

    // Chi nguoi tao cong viec duoc thu gui lai email
    const share = await TaskShare.findOne({
      taskId: task._id,
      userId: req.user._id
    });
    const permissions = getTaskPermissions(task, req.user._id, share);

    if (!permissions.canViewEmailLogs) {
      return res.status(403).json({
        message: 'Ban khong co quyen thu gui lai email cua cong viec nay'
      });
    }

    if (log.status !== 'failed') {
      return res.status(400).json({
        message: 'Chi co the thu gui lai email da that bai'
      });
    }

    if (log.attempts >= MAX_ATTEMPTS) {
      return res.status(400).json({
        message: `Email da thu gui ${log.attempts} lan, khong the thu lai`
      });
    }

    const updated = await retryEmailLog(log);

    return res.status(200).json({
      message: updated.status === 'sent'
        ? 'Gui lai email thanh cong'
        : 'Gui lai email that bai',
      emailLog: formatEmailLog(updated)
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTaskEmailLogs,
  retryEmailLogById,
  formatEmailLog
};
