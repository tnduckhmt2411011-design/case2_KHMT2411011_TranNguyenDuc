const port = Number.parseInt(process.env.SMTP_PORT || '587', 10);

const emailConfig = {
  host: process.env.SMTP_HOST || '',
  port: Number.isNaN(port) ? 587 : port,
  secure: String(process.env.SMTP_SECURE || 'false').toLowerCase() === 'true',
  user: process.env.SMTP_USER || '',
  pass: process.env.SMTP_PASS || '',
  from: process.env.EMAIL_FROM || 'Task Manager <no-reply@taskmanager.local>'
};

// Chi coi la da cau hinh khi co host SMTP. Khong bao gio ghi log thong tin dang nhap.
emailConfig.isConfigured = Boolean(emailConfig.host);

module.exports = emailConfig;
