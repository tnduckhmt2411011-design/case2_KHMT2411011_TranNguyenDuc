const STATUS_LABELS = {
  todo: 'Chưa thực hiện',
  in_progress: 'Đang thực hiện',
  completed: 'Đã hoàn thành'
};

const PRIORITY_LABELS = {
  low: 'Thấp',
  medium: 'Trung bình',
  high: 'Cao'
};

const escapeHtml = (value) => {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
};

const formatDateTime = (value) => {
  if (!value) return 'Chưa thiết lập';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Chưa thiết lập';
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh'
  }).format(date);
};

const buildTaskRows = (task, extra = {}) => {
  const rows = [
    ['Công việc', task.title || ''],
    ['Trạng thái', STATUS_LABELS[task.status] || task.status || ''],
    ['Mức độ ưu tiên', PRIORITY_LABELS[task.priority] || task.priority || ''],
    ['Hạn hoàn thành', formatDateTime(task.dueDate)]
  ];

  if (extra.oldDueDate) {
    rows.push(['Hạn hoàn thành cũ', formatDateTime(extra.oldDueDate)]);
  }

  if (extra.permission) {
    rows.push([
      'Quyền truy cập',
      extra.permission === 'editor' ? 'Chỉnh sửa (editor)' : 'Chỉ xem (viewer)'
    ]);
  }

  return rows;
};

const buildHtml = ({ headline, intro, task, extra }) => {
  const rows = buildTaskRows(task, extra);
  const tableRows = rows
    .map(
      ([label, value]) =>
        `<tr><td style="padding:8px 12px;border-bottom:1px solid #e5e7eb;color:#4b5563;width:180px;">${escapeHtml(
          label
        )}</td><td style="padding:8px 12px;border-bottom:1px solid #e5e7eb;color:#111827;font-weight:600;">${escapeHtml(
          value
        )}</td></tr>`
    )
    .join('');

  return `<!doctype html>
<html lang="vi">
  <body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f3f4f6;padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e5e7eb;">
            <tr>
              <td style="background:#1d4ed8;color:#ffffff;padding:20px 24px;">
                <div style="font-size:20px;font-weight:bold;">Task Manager</div>
                <div style="font-size:13px;opacity:.9;margin-top:4px;">Thông báo công việc</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px;">
                <h2 style="margin:0 0 12px;font-size:18px;color:#111827;">${escapeHtml(headline)}</h2>
                <p style="margin:0 0 16px;line-height:1.6;color:#374151;">${intro}</p>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;border:1px solid #e5e7eb;border-radius:8px;">
                  ${tableRows}
                </table>
                <p style="margin:20px 0 0;font-size:13px;color:#6b7280;line-height:1.5;">Email này được gửi tự động từ ứng dụng Task Manager. Vui lòng không trả lời email này.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
};

const buildText = ({ headline, intro, task, extra }) => {
  const lines = [
    'Task Manager',
    headline,
    '',
    intro.replace(/<[^>]+>/g, ''),
    '',
    ...buildTaskRows(task, extra).map(([label, value]) => `${label}: ${value}`),
    '',
    'Email này được gửi tự động từ ứng dụng Task Manager.'
  ];
  return lines.join('\n');
};

/**
 * Tao noi dung email cho mot su kien cong viec.
 * @param {string} eventType task_assigned | task_shared | task_due_changed | task_completed
 * @param {{task: object, recipient: object, actor: object, extra?: object}} context
 * @returns {{subject: string, html: string, text: string}}
 */
const buildEmail = (eventType, { task, recipient, actor, extra = {} }) => {
  const safeTask = task || {};
  const recipientName = recipient?.fullName || recipient?.email || 'bạn';
  const actorName = actor?.fullName || 'Một thành viên';
  const taskTitle = safeTask.title || 'công việc';

  let headline = 'Thông báo công việc';
  let subject = `[Task Manager] Thông báo công việc: ${taskTitle}`;
  let intro = '';

  switch (eventType) {
    case 'task_assigned':
      headline = 'Bạn được giao một công việc mới';
      subject = `[Task Manager] Bạn được giao công việc: ${taskTitle}`;
      intro = `Xin chào ${escapeHtml(
        recipientName
      )}, <strong>${escapeHtml(actorName)}</strong> đã giao cho bạn công việc <strong>${escapeHtml(
        taskTitle
      )}</strong>. Vui lòng mở ứng dụng Task Manager để xem chi tiết và cập nhật tiến độ.`;
      break;
    case 'task_shared': {
      const permission = extra.permission === 'editor' ? 'chỉnh sửa' : 'chỉ xem';
      headline = 'Bạn được chia sẻ một công việc';
      subject = `[Task Manager] Bạn được chia sẻ công việc: ${taskTitle}`;
      intro = `Xin chào ${escapeHtml(
        recipientName
      )}, <strong>${escapeHtml(actorName)}</strong> đã chia sẻ công việc <strong>${escapeHtml(
        taskTitle
      )}</strong> cho bạn với quyền <strong>${permission}</strong>.`;
      break;
    }
    case 'task_due_changed':
      headline = 'Hạn hoàn thành công việc đã thay đổi';
      subject = `[Task Manager] Hạn hoàn thành đã thay đổi: ${taskTitle}`;
      intro = `Xin chào ${escapeHtml(
        recipientName
      )}, <strong>${escapeHtml(actorName)}</strong> đã thay đổi hạn hoàn thành công việc <strong>${escapeHtml(
        taskTitle
      )}</strong>. Hạn mới là <strong>${escapeHtml(formatDateTime(safeTask.dueDate))}</strong>.`;
      break;
    case 'task_completed':
      headline = 'Công việc đã hoàn thành';
      subject = `[Task Manager] Công việc đã hoàn thành: ${taskTitle}`;
      intro = `Xin chào ${escapeHtml(
        recipientName
      )}, <strong>${escapeHtml(actorName)}</strong> đã đánh dấu công việc <strong>${escapeHtml(
        taskTitle
      )}</strong> là đã hoàn thành.`;
      break;
    default:
      intro = `Xin chào ${escapeHtml(
        recipientName
      )}, có cập nhật mới cho công việc <strong>${escapeHtml(taskTitle)}</strong>.`;
      break;
  }

  return {
    subject,
    html: buildHtml({ headline, intro, task: safeTask, extra }),
    text: buildText({ headline, intro, task: safeTask, extra })
  };
};

module.exports = {
  buildEmail,
  formatDateTime,
  escapeHtml,
  STATUS_LABELS,
  PRIORITY_LABELS
};
