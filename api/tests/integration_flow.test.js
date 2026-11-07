const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const mongoose = require('mongoose');
const path = require('node:path');

// Ensure SMTP is mocked before loading any app logic
process.env.SMTP_HOST = '';
process.env.SMTP_USER = '';
process.env.SMTP_PASS = '';

require('dotenv').config({ path: path.join(__dirname, '../.env') });

const app = require('../src/app');
const User = require('../src/models/User');
const Task = require('../src/models/Task');
const TaskShare = require('../src/models/TaskShare');
const TaskActivity = require('../src/models/TaskActivity');
const Notification = require('../src/models/Notification');
const EmailLog = require('../src/models/EmailLog');

describe('End-to-End Integration Flow Tests - Buoi 3 (F3)', () => {
  let server;
  let port;
  const runId = Date.now().toString().slice(-6);

  const createdUserIds = [];
  const createdTaskIds = [];

  let creator;
  let assignee;
  let editor;

  let taskId;
  let shareId;

  const reqApi = (method, reqPath, body, token) => new Promise((resolve, reject) => {
    const sBody = body ? JSON.stringify(body) : '';
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: reqPath,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(sBody ? { 'Content-Length': Buffer.byteLength(sBody) } : {}),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: data ? JSON.parse(data) : {} });
        } catch (_) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (sBody) req.write(sBody);
    req.end();
  });

  const registerAndLogin = async (role) => {
    const email = `test+flow_${role}_${runId}@example.test`;
    const regRes = await reqApi('POST', '/api/auth/register', {
      fullName: `Test Flow ${role}`,
      email,
      password: 'Password123!',
      confirmPassword: 'Password123!'
    });
    assert.strictEqual(regRes.status, 201, `Failed to register ${role}: ${JSON.stringify(regRes.body)}`);
    const userId = regRes.body.user.id;
    createdUserIds.push(userId);

    const loginRes = await reqApi('POST', '/api/auth/login', {
      email,
      password: 'Password123!'
    });
    assert.strictEqual(loginRes.status, 200, `Failed to login ${role}`);
    return { id: userId, email, token: loginRes.body.token, fullName: `Test Flow ${role}` };
  };

  before(async () => {
    await mongoose.connect(process.env.MONGODB_URI);
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    port = server.address().port;

    creator = await registerAndLogin('creator');
    assignee = await registerAndLogin('assignee');
    editor = await registerAndLogin('editor');
  });

  after(async () => {
    try {
      if (createdTaskIds.length > 0) {
        await Task.deleteMany({ _id: { $in: createdTaskIds } });
        await TaskShare.deleteMany({ taskId: { $in: createdTaskIds } });
        await TaskActivity.deleteMany({ taskId: { $in: createdTaskIds } });
        await Notification.deleteMany({ taskId: { $in: createdTaskIds } });
        await EmailLog.deleteMany({ taskId: { $in: createdTaskIds } });
      }
      if (createdUserIds.length > 0) {
        await User.deleteMany({ _id: { $in: createdUserIds } });
        await Notification.deleteMany({ userId: { $in: createdUserIds } });
      }
      // Backup cleanup for matching runId patterns
      await User.deleteMany({ email: new RegExp(`^test\\+flow_.*_${runId}@example\\.test$`) });
      await Task.deleteMany({ title: new RegExp(`\\[TEST\\] Flow.*${runId}`) });
    } catch (err) {
      console.error('Error during test cleanup:', err.message);
    }

    if (server) server.close();
    await mongoose.disconnect();
  });

  test('Step 1: Check GET /api/auth/me for 3 registered users', async () => {
    for (const user of [creator, assignee, editor]) {
      const res = await reqApi('GET', '/api/auth/me', null, user.token);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.user.id, user.id);
      assert.strictEqual(res.body.user.email, user.email);
      assert.strictEqual(res.body.user.fullName, user.fullName);
    }
  });

  test('Step 2: Creator creates new task (POST /api/tasks)', async () => {
    const dueDate = new Date(Date.now() + 86400000 * 3).toISOString();
    const res = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Flow Task Buoi 3 ${runId}`,
      description: 'Integration flow testing Buoi 3 features',
      priority: 'high',
      status: 'todo',
      dueDate
    }, creator.token);

    assert.strictEqual(res.status, 201);
    assert.ok(res.body.task);
    assert.strictEqual(res.body.task.title, `[TEST] Flow Task Buoi 3 ${runId}`);
    assert.strictEqual(res.body.task.status, 'todo');
    assert.strictEqual(res.body.task.priority, 'high');
    assert.strictEqual(res.body.task.createdBy.id, creator.id);

    taskId = res.body.task.id;
    createdTaskIds.push(taskId);
  });

  test('Step 3: Creator searches & filters tasks (GET /api/tasks?q=...&status=...&priority=...&sortBy=...&order=...)', async () => {
    const q = encodeURIComponent(`[TEST] Flow Task Buoi 3 ${runId}`);
    const res = await reqApi(
      'GET',
      `/api/tasks?q=${q}&status=todo&priority=high&sortBy=dueDate&order=asc`,
      null,
      creator.token
    );

    assert.strictEqual(res.status, 200);
    assert.ok(Array.isArray(res.body.tasks));
    const found = res.body.tasks.find(t => t.id === taskId);
    assert.ok(found, 'Task created in Step 2 must be found via search & filter');
    assert.strictEqual(found.title, `[TEST] Flow Task Buoi 3 ${runId}`);
  });

  test('Step 4: Creator assigns task to Assignee (POST /api/tasks/:id/assignees)', async () => {
    const res = await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [assignee.id],
      primaryAssigneeId: assignee.id
    }, creator.token);

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.task);
    assert.ok(Array.isArray(res.body.task.assignees));
    const foundAssignee = res.body.task.assignees.find(a => a.id === assignee.id);
    assert.ok(foundAssignee, 'Assignee must be in task assignees list');
    assert.strictEqual(res.body.task.primaryAssignee.id, assignee.id);
  });

  test('Step 5: Creator shares edit permission to Editor (POST /api/tasks/:id/shares)', async () => {
    const res = await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [editor.id],
      permission: 'editor'
    }, creator.token);

    assert.strictEqual(res.status, 201);
    assert.ok(Array.isArray(res.body.created));
    const foundShare = res.body.created.find(s => s.user && s.user.id === editor.id);
    assert.ok(foundShare, 'Editor must be in created shares list with editor permission');
    assert.strictEqual(foundShare.permission, 'editor');

    shareId = foundShare.id;
    assert.ok(shareId, 'Share record must have an ID');
  });

  test('Step 6: Editor updates task status (PATCH /api/tasks/:id/status)', async () => {
    const res = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'in_progress'
    }, editor.token);

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.task.status, 'in_progress');
  });

  test('Step 7: Verify in-app notifications, unread-count, mark-as-read, and mark-all-as-read', async () => {
    // 7.1 Verify Assignee received notifications (task_assigned & task_status_changed)
    const assigneeNotifRes = await reqApi('GET', '/api/notifications', null, assignee.token);
    assert.strictEqual(assigneeNotifRes.status, 200);
    const assigneeNotifs = assigneeNotifRes.body.notifications;
    assert.ok(assigneeNotifs.length >= 2, 'Assignee must have at least 2 notifications');

    const assignedNotif = assigneeNotifs.find(n => n.type === 'task_assigned' && n.taskId === taskId);
    assert.ok(assignedNotif, 'Assignee must receive task_assigned notification');

    const statusNotif = assigneeNotifs.find(n => n.type === 'task_status_changed' && n.taskId === taskId);
    assert.ok(statusNotif, 'Assignee must receive task_status_changed notification');

    // 7.2 Verify Editor received task_shared notification, but did NOT receive self-action notification
    const editorNotifRes = await reqApi('GET', '/api/notifications', null, editor.token);
    assert.strictEqual(editorNotifRes.status, 200);
    const editorNotifs = editorNotifRes.body.notifications;
    const sharedNotif = editorNotifs.find(n => n.type === 'task_shared' && n.taskId === taskId);
    assert.ok(sharedNotif, 'Editor must receive task_shared notification');
    const editorSelfNotif = editorNotifs.find(n => n.type === 'task_status_changed' && n.taskId === taskId);
    assert.strictEqual(editorSelfNotif, undefined, 'Editor must NOT receive notification for their own status change');

    // 7.3 Verify Creator did NOT receive self-action notification for assigning or sharing
    const creatorNotifRes = await reqApi('GET', '/api/notifications', null, creator.token);
    assert.strictEqual(creatorNotifRes.status, 200);
    const creatorNotifs = creatorNotifRes.body.notifications;
    const creatorSelfAssign = creatorNotifs.find(n => n.type === 'task_assigned' && n.taskId === taskId);
    assert.strictEqual(creatorSelfAssign, undefined, 'Creator must NOT receive notification for assigning task');
    const creatorSelfShare = creatorNotifs.find(n => n.type === 'task_shared' && n.taskId === taskId);
    assert.strictEqual(creatorSelfShare, undefined, 'Creator must NOT receive notification for sharing task');

    // 7.4 Test unread-count and mark-as-read for Assignee
    const unreadCountRes1 = await reqApi('GET', '/api/notifications/unread-count', null, assignee.token);
    assert.strictEqual(unreadCountRes1.status, 200);
    const initialUnread = unreadCountRes1.body.count;
    assert.ok(initialUnread >= 2, 'Initial unread count should be >= 2');

    // Mark single notification as read
    const singleNotifId = assignedNotif.id;
    const markReadRes = await reqApi('PATCH', `/api/notifications/${singleNotifId}/read`, null, assignee.token);
    assert.strictEqual(markReadRes.status, 200);
    assert.strictEqual(markReadRes.body.notification.isRead, true);

    const unreadCountRes2 = await reqApi('GET', '/api/notifications/unread-count', null, assignee.token);
    assert.strictEqual(unreadCountRes2.status, 200);
    assert.strictEqual(unreadCountRes2.body.count, initialUnread - 1);

    // Mark all as read
    const markAllRes = await reqApi('PATCH', '/api/notifications/read-all', null, assignee.token);
    assert.strictEqual(markAllRes.status, 200);
    assert.ok(markAllRes.body.modifiedCount >= 1);

    const unreadCountRes3 = await reqApi('GET', '/api/notifications/unread-count', null, assignee.token);
    assert.strictEqual(unreadCountRes3.status, 200);
    assert.strictEqual(unreadCountRes3.body.count, 0);
  });

  test('Step 8: Creator inspects email logs (GET /api/tasks/:id/email-logs)', async () => {
    const res = await reqApi('GET', `/api/tasks/${taskId}/email-logs`, null, creator.token);
    assert.strictEqual(res.status, 200);
    assert.ok(Array.isArray(res.body.emailLogs));

    const assignLog = res.body.emailLogs.find(l => l.eventType === 'task_assigned' && l.recipientEmail === assignee.email);
    assert.ok(assignLog, 'EmailLog must record task_assigned event for assignee');
    assert.ok(['failed', 'sent'].includes(assignLog.status), `Log status must be sent or failed, got: ${assignLog.status}`);

    const shareLog = res.body.emailLogs.find(l => l.eventType === 'task_shared' && l.recipientEmail === editor.email);
    assert.ok(shareLog, 'EmailLog must record task_shared event for editor');
    assert.ok(['failed', 'sent'].includes(shareLog.status), `Log status must be sent or failed, got: ${shareLog.status}`);
  });

  test('Step 9: Verify statistics endpoints (/api/statistics/tasks, /assignments, /deadlines)', async () => {
    // 9.1 Creator task statistics
    const taskStatRes = await reqApi('GET', '/api/statistics/tasks', null, creator.token);
    assert.strictEqual(taskStatRes.status, 200);
    assert.ok(taskStatRes.body.total >= 1);
    assert.ok(taskStatRes.body.byStatus.in_progress >= 1);

    // 9.2 Assignee assignment statistics
    const assignStatRes = await reqApi('GET', '/api/statistics/assignments', null, assignee.token);
    assert.strictEqual(assignStatRes.status, 200);
    assert.ok(assignStatRes.body.totalAssigned >= 1);
    assert.ok(assignStatRes.body.totalPrimary >= 1);
    assert.ok(assignStatRes.body.assignedByStatus.in_progress >= 1);

    // 9.3 Creator deadline statistics
    const deadlineStatRes = await reqApi('GET', '/api/statistics/deadlines?days=7', null, creator.token);
    assert.strictEqual(deadlineStatRes.status, 200);
    assert.ok(Array.isArray(deadlineStatRes.body.upcoming));
    const upcomingTask = deadlineStatRes.body.upcoming.find(t => t.id === taskId);
    assert.ok(upcomingTask, 'Task with due date in 3 days must appear in upcoming deadlines');
    assert.strictEqual(upcomingTask.status, 'in_progress');
  });

  test('Step 10: Creator revokes share permission (DELETE /api/tasks/:id/shares/:shareId)', async () => {
    const res = await reqApi('DELETE', `/api/tasks/${taskId}/shares/${shareId}`, null, creator.token);
    assert.strictEqual(res.status, 200);

    // Verify share is gone
    const checkSharesRes = await reqApi('GET', `/api/tasks/${taskId}/shares`, null, creator.token);
    assert.strictEqual(checkSharesRes.status, 200);
    const remaining = checkSharesRes.body.shares.find(s => s.id === shareId);
    assert.strictEqual(remaining, undefined, 'Revoked share record should not exist');
  });

  test('Step 11: Creator deletes task (DELETE /api/tasks/:id) - task is deleted, Notification and EmailLog preserved', async () => {
    const res = await reqApi('DELETE', `/api/tasks/${taskId}`, null, creator.token);
    assert.strictEqual(res.status, 200);

    // Verify task is deleted (404)
    const checkTaskRes = await reqApi('GET', `/api/tasks/${taskId}`, null, creator.token);
    assert.strictEqual(checkTaskRes.status, 404);

    // Verify Notification and EmailLog are preserved in DB as audit trail
    const remainingNotifs = await Notification.find({ taskId: new mongoose.Types.ObjectId(taskId) });
    assert.ok(remainingNotifs.length > 0, 'Notifications for deleted task must be preserved for audit trail');

    const remainingLogs = await EmailLog.find({ taskId: new mongoose.Types.ObjectId(taskId) });
    assert.ok(remainingLogs.length > 0, 'EmailLogs for deleted task must be preserved for audit trail');

    // Verify TaskShare and TaskActivity for this task are deleted
    const remainingShares = await TaskShare.find({ taskId: new mongoose.Types.ObjectId(taskId) });
    assert.strictEqual(remainingShares.length, 0, 'TaskShares must be cascade deleted');

    const remainingActivities = await TaskActivity.find({ taskId: new mongoose.Types.ObjectId(taskId) });
    assert.strictEqual(remainingActivities.length, 0, 'TaskActivities must be cascade deleted');
  });
});
