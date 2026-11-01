const nodemailer = require('nodemailer');
const mongoose = require('mongoose');
const emailConfig = require('../config/email');
const EmailLog = require('../models/EmailLog');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const User = require('../models/User');
const { buildEmail } = require('../utils/emailTemplates');

const MAX_ATTEMPTS = 5;

let transporter = null;

const getTransporter = () => {
  if (!emailConfig.isConfigured) return null;

  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: emailConfig.host,
      port: emailConfig.port,
      secure: emailConfig.secure,
      auth: emailConfig.user
        ? { user: emailConfig.user, pass: emailConfig.pass }
        : undefined,
      connectionTimeout: 5000,
      greetingTimeout: 5000,
      socketTimeout: 10000
    });
  }

  return transporter;
};

const toIdString = (value) => {
  if (!value) return null;
  return (value._id || value).toString();
};

const resolveRecipients = async (recipients = [], actorId = null) => {
  const actorIdStr = toIdString(actorId);
  const ids = [...new Set(
    recipients
      .map((recipient) => toIdString(recipient))
      .filter(Boolean)
  )].filter((id) => id !== actorIdStr && mongoose.Types.ObjectId.isValid(id));

  if (ids.length === 0) return [];

  const users = await User.find({ _id: { $in: ids } }).select('fullName email');
  const seenEmails = new Set();

  return users.filter((user) => {
    const email = (user.email || '').toLowerCase();
    if (!email || seenEmails.has(email)) return false;
    seenEmails.add(email);
    return true;
  });
};

const deliverEmail = async (log, content) => {
  log.attempts = (log.attempts || 0) + 1;

  const mailer = getTransporter();
  if (!mailer) {
    log.status = 'failed';
    log.errorMessage = 'Chua cau hinh SMTP tren may chu. Vui long kiem tra bien moi truong.';
    await log.save();
    return log;
  }

  try {
    await mailer.sendMail({
      from: emailConfig.from,
      to: log.recipientEmail,
      subject: content.subject,
      html: content.html,
      text: content.text
    });

    log.status = 'sent';
    log.sentAt = new Date();
    log.errorMessage = '';
  } catch (error) {
    log.status = 'failed';
    log.errorMessage = String(error.message || error).slice(0, 500);
  }

  await log.save();
  return log;
};

const sendEventEmail = async ({ task, recipient, eventType, actor, extra = {} }) => {
  if (!recipient || !recipient.email) return null;

  const content = buildEmail(eventType, { task, recipient, actor, extra });
  const log = await EmailLog.create({
    taskId: task ? task._id : null,
    recipientEmail: recipient.email,
    eventType,
    subject: content.subject,
    status: 'pending',
    attempts: 0
  });

  return deliverEmail(log, content);
};

const sendEmailsToRecipients = async ({
  task,
  actor,
  recipients,
  eventType,
  extra = {}
}) => {
  try {
    const resolved = await resolveRecipients(recipients, actor ? actor._id : null);
    if (resolved.length === 0) return [];

    const results = await Promise.allSettled(
      resolved.map((recipient) =>
        sendEventEmail({ task, recipient, eventType, actor, extra })
      )
    );

    return results;
  } catch (error) {
    // Gui email la tac vu phu, khong duoc lam hong nghiep vu chinh
    console.error('Loi gui email thong bao:', error.message);
    return [];
  }
};

const sendTaskAssignedEmails = async ({ task, actor, recipients }) => {
  return sendEmailsToRecipients({
    task,
    actor,
    recipients,
    eventType: 'task_assigned'
  });
};

const sendTaskSharedEmails = async ({ task, actor, recipients, permission }) => {
  return sendEmailsToRecipients({
    task,
    actor,
    recipients,
    eventType: 'task_shared',
    extra: { permission }
  });
};

const sendTaskDueChangedEmails = async ({ task, actor, recipients, oldDueDate }) => {
  return sendEmailsToRecipients({
    task,
    actor,
    recipients,
    eventType: 'task_due_changed',
    extra: { oldDueDate }
  });
};

const sendTaskCompletedEmails = async ({ task, actor, recipients }) => {
  return sendEmailsToRecipients({
    task,
    actor,
    recipients,
    eventType: 'task_completed'
  });
};

/**
 * Thu gui lai mot email da that bai. Dung lai noi dung tu du lieu cong viec.
 * @param {object} log EmailLog document
 */
const retryEmailLog = async (log) => {
  if (log.attempts >= MAX_ATTEMPTS) {
    const error = new Error(`Email da thu gui ${log.attempts} lan, khong the thu lai`);
    error.statusCode = 400;
    throw error;
  }

  const task = log.taskId
    ? await Task.findById(log.taskId).populate('createdBy', 'fullName email')
    : null;

  if (!task) {
    const error = new Error('Khong tim thay cong viec cua email nay');
    error.statusCode = 400;
    throw error;
  }

  const recipientUser = await User.findOne({ email: log.recipientEmail })
    .select('fullName email');
  const recipient = recipientUser || {
    fullName: log.recipientEmail,
    email: log.recipientEmail
  };

  let permission = null;
  if (log.eventType === 'task_shared' && recipientUser) {
    const share = await TaskShare.findOne({
      taskId: task._id,
      userId: recipientUser._id
    });
    permission = share ? share.permission : null;
  }

  const content = buildEmail(log.eventType, {
    task,
    recipient,
    actor: task.createdBy,
    extra: { permission }
  });

  // Giu nguyen tieu de da luu de lich su nhat quan
  content.subject = log.subject;

  return deliverEmail(log, content);
};

module.exports = {
  sendEventEmail,
  sendTaskAssignedEmails,
  sendTaskSharedEmails,
  sendTaskDueChangedEmails,
  sendTaskCompletedEmails,
  retryEmailLog,
  resolveRecipients,
  MAX_ATTEMPTS
};
