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

describe('Task CRUD Permission Matrix Tests (F2)', () => {
  let server;
  let port;
  const runId = Date.now().toString().slice(-6);

  const createdUserIds = [];
  const createdTaskIds = [];

  let creator;
  let editor;
  let assignee;
  let viewer;
  let stranger;
  let comboUser; // Assignee + Viewer

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
    const email = `test+perm_${role}_${runId}@example.test`;
    const regRes = await reqApi('POST', '/api/auth/register', {
      fullName: `Test ${role}`,
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
    return { id: userId, email, token: loginRes.body.token };
  };

  before(async () => {
    await mongoose.connect(process.env.MONGODB_URI);
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    port = server.address().port;

    creator = await registerAndLogin('creator');
    editor = await registerAndLogin('editor');
    assignee = await registerAndLogin('assignee');
    viewer = await registerAndLogin('viewer');
    stranger = await registerAndLogin('stranger');
    comboUser = await registerAndLogin('combo');
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
      // Backup cleanup for matching prefix
      await User.deleteMany({ email: new RegExp(`^test\\+perm_.*_${runId}@example\\.test$`) });
      await Task.deleteMany({ title: new RegExp(`\\[TEST\\] Perm.*${runId}`) });
    } catch (err) {
      console.error('Error during test cleanup:', err.message);
    }

    if (server) server.close();
    await mongoose.disconnect();
  });

  test('1. View detail: Creator, Editor, Assignee, Viewer allowed (200), Stranger blocked (403)', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 1 ${runId}`,
      description: 'Detail view test',
      priority: 'high',
      status: 'todo'
    }, creator.token);
    assert.strictEqual(taskRes.status, 201);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    // Giao việc cho assignee
    await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [assignee.id],
      primaryAssigneeId: assignee.id
    }, creator.token);

    // Chia sẻ cho editor và viewer
    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [editor.id],
      permission: 'editor'
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [viewer.id],
      permission: 'viewer'
    }, creator.token);

    // Creator view
    const cRes = await reqApi('GET', `/api/tasks/${taskId}`, null, creator.token);
    assert.strictEqual(cRes.status, 200);
    assert.strictEqual(cRes.body.task.permissions.canEdit, true);
    assert.strictEqual(cRes.body.task.permissions.canChangeStatus, true);
    assert.strictEqual(cRes.body.task.permissions.canDelete, true);
    assert.strictEqual(cRes.body.task.permissions.canAssign, true);
    assert.strictEqual(cRes.body.task.permissions.canShare, true);
    assert.strictEqual(cRes.body.task.permissions.canViewEmailLogs, true);

    // Editor view
    const eRes = await reqApi('GET', `/api/tasks/${taskId}`, null, editor.token);
    assert.strictEqual(eRes.status, 200);
    assert.strictEqual(eRes.body.task.permissions.canEdit, true);
    assert.strictEqual(eRes.body.task.permissions.canChangeStatus, true);
    assert.strictEqual(eRes.body.task.permissions.canDelete, false);
    assert.strictEqual(eRes.body.task.permissions.canAssign, false);
    assert.strictEqual(eRes.body.task.permissions.canShare, false);
    assert.strictEqual(eRes.body.task.permissions.canViewEmailLogs, false);

    // Assignee view
    const aRes = await reqApi('GET', `/api/tasks/${taskId}`, null, assignee.token);
    assert.strictEqual(aRes.status, 200);
    assert.strictEqual(aRes.body.task.permissions.canEdit, false);
    assert.strictEqual(aRes.body.task.permissions.canChangeStatus, true);
    assert.strictEqual(aRes.body.task.permissions.canDelete, false);
    assert.strictEqual(aRes.body.task.permissions.canViewEmailLogs, false);

    // Viewer view
    const vRes = await reqApi('GET', `/api/tasks/${taskId}`, null, viewer.token);
    assert.strictEqual(vRes.status, 200);
    assert.strictEqual(vRes.body.task.permissions.canEdit, false);
    assert.strictEqual(vRes.body.task.permissions.canChangeStatus, false);
    assert.strictEqual(vRes.body.task.permissions.canDelete, false);
    assert.strictEqual(vRes.body.task.permissions.canViewEmailLogs, false);

    // Stranger view
    const sRes = await reqApi('GET', `/api/tasks/${taskId}`, null, stranger.token);
    assert.strictEqual(sRes.status, 403);
  });

  test('2. PUT update task: Creator & Editor allowed, Assignee, Viewer, Stranger blocked (403) and data untouched', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 2 Original ${runId}`,
      priority: 'medium',
      status: 'todo'
    }, creator.token);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [assignee.id],
      primaryAssigneeId: assignee.id
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [editor.id],
      permission: 'editor'
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [viewer.id],
      permission: 'viewer'
    }, creator.token);

    // Assignee tries PUT -> 403
    const aPut = await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: 'Hacked by Assignee'
    }, assignee.token);
    assert.strictEqual(aPut.status, 403);

    // Viewer tries PUT -> 403
    const vPut = await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: 'Hacked by Viewer'
    }, viewer.token);
    assert.strictEqual(vPut.status, 403);

    // Stranger tries PUT -> 403
    const sPut = await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: 'Hacked by Stranger'
    }, stranger.token);
    assert.strictEqual(sPut.status, 403);

    // Verify task title is UNTOUCHED in DB
    const checkDoc1 = await Task.findById(taskId);
    assert.strictEqual(checkDoc1.title, `[TEST] Perm Task 2 Original ${runId}`);

    // Editor PUT -> 200
    const ePut = await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: `[TEST] Perm Task 2 by Editor ${runId}`
    }, editor.token);
    assert.strictEqual(ePut.status, 200);

    const checkDoc2 = await Task.findById(taskId);
    assert.strictEqual(checkDoc2.title, `[TEST] Perm Task 2 by Editor ${runId}`);

    // Creator PUT -> 200
    const cPut = await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: `[TEST] Perm Task 2 by Creator ${runId}`
    }, creator.token);
    assert.strictEqual(cPut.status, 200);

    const checkDoc3 = await Task.findById(taskId);
    assert.strictEqual(checkDoc3.title, `[TEST] Perm Task 2 by Creator ${runId}`);
  });

  test('3. PATCH status: Creator, Editor, Assignee allowed, Viewer & Stranger blocked (403)', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 3 Status ${runId}`,
      priority: 'medium',
      status: 'todo'
    }, creator.token);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [assignee.id],
      primaryAssigneeId: assignee.id
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [editor.id],
      permission: 'editor'
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [viewer.id],
      permission: 'viewer'
    }, creator.token);

    // Viewer tries PATCH -> 403
    const vPatch = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'in_progress'
    }, viewer.token);
    assert.strictEqual(vPatch.status, 403);

    // Stranger tries PATCH -> 403
    const sPatch = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'completed'
    }, stranger.token);
    assert.strictEqual(sPatch.status, 403);

    // Verify status untouched
    let doc = await Task.findById(taskId);
    assert.strictEqual(doc.status, 'todo');

    // Assignee PATCH -> 200
    const aPatch = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'in_progress'
    }, assignee.token);
    assert.strictEqual(aPatch.status, 200);
    doc = await Task.findById(taskId);
    assert.strictEqual(doc.status, 'in_progress');

    // Editor PATCH -> 200
    const ePatch = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'completed'
    }, editor.token);
    assert.strictEqual(ePatch.status, 200);
    doc = await Task.findById(taskId);
    assert.strictEqual(doc.status, 'completed');

    // Creator PATCH -> 200
    const cPatch = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'todo'
    }, creator.token);
    assert.strictEqual(cPatch.status, 200);
    doc = await Task.findById(taskId);
    assert.strictEqual(doc.status, 'todo');
  });

  test('4. Admin actions (DELETE, Assign, Share, EmailLogs): Only Creator allowed (200), all others 403', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 4 Admin ${runId}`,
      status: 'todo'
    }, creator.token);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [assignee.id],
      primaryAssigneeId: assignee.id
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [editor.id],
      permission: 'editor'
    }, creator.token);

    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [viewer.id],
      permission: 'viewer'
    }, creator.token);

    // Email logs
    assert.strictEqual((await reqApi('GET', `/api/tasks/${taskId}/email-logs`, null, creator.token)).status, 200);
    assert.strictEqual((await reqApi('GET', `/api/tasks/${taskId}/email-logs`, null, editor.token)).status, 403);
    assert.strictEqual((await reqApi('GET', `/api/tasks/${taskId}/email-logs`, null, assignee.token)).status, 403);
    assert.strictEqual((await reqApi('GET', `/api/tasks/${taskId}/email-logs`, null, viewer.token)).status, 403);
    assert.strictEqual((await reqApi('GET', `/api/tasks/${taskId}/email-logs`, null, stranger.token)).status, 403);

    // Assign
    assert.strictEqual((await reqApi('POST', `/api/tasks/${taskId}/assignees`, { userIds: [editor.id] }, editor.token)).status, 403);
    assert.strictEqual((await reqApi('POST', `/api/tasks/${taskId}/assignees`, { userIds: [viewer.id] }, viewer.token)).status, 403);
    assert.strictEqual((await reqApi('POST', `/api/tasks/${taskId}/assignees`, { userIds: [stranger.id] }, stranger.token)).status, 403);

    // Share
    assert.strictEqual((await reqApi('POST', `/api/tasks/${taskId}/shares`, { userIds: [stranger.id], permission: 'viewer' }, editor.token)).status, 403);
    assert.strictEqual((await reqApi('POST', `/api/tasks/${taskId}/shares`, { userIds: [stranger.id], permission: 'viewer' }, assignee.token)).status, 403);
    assert.strictEqual((await reqApi('POST', `/api/tasks/${taskId}/shares`, { userIds: [stranger.id], permission: 'viewer' }, viewer.token)).status, 403);

    // Delete
    assert.strictEqual((await reqApi('DELETE', `/api/tasks/${taskId}`, null, editor.token)).status, 403);
    assert.strictEqual((await reqApi('DELETE', `/api/tasks/${taskId}`, null, assignee.token)).status, 403);
    assert.strictEqual((await reqApi('DELETE', `/api/tasks/${taskId}`, null, viewer.token)).status, 403);
    assert.strictEqual((await reqApi('DELETE', `/api/tasks/${taskId}`, null, stranger.token)).status, 403);
    assert.ok(await Task.findById(taskId));

    // Creator delete -> 200
    const cDel = await reqApi('DELETE', `/api/tasks/${taskId}`, null, creator.token);
    assert.strictEqual(cDel.status, 200);
    assert.strictEqual(await Task.findById(taskId), null);
  });

  test('5. Combo User (Assignee + Viewer): role union allows status change but blocks PUT', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 5 Combo ${runId}`,
      status: 'todo'
    }, creator.token);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    // Gán comboUser làm Assignee
    await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [comboUser.id],
      primaryAssigneeId: comboUser.id
    }, creator.token);

    // Đồng thời chia sẻ quyền Viewer
    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [comboUser.id],
      permission: 'viewer'
    }, creator.token);

    // Combo user xem task detail
    const detailRes = await reqApi('GET', `/api/tasks/${taskId}`, null, comboUser.token);
    assert.strictEqual(detailRes.status, 200);
    // Role union: canChangeStatus is true from Assignee, canEdit is false from both
    assert.strictEqual(detailRes.body.task.permissions.canChangeStatus, true);
    assert.strictEqual(detailRes.body.task.permissions.canEdit, false);

    // Combo user PATCH status -> 200
    const patchRes = await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'in_progress'
    }, comboUser.token);
    assert.strictEqual(patchRes.status, 200);

    // Combo user PUT info -> 403
    const putRes = await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: 'Hacked by ComboUser'
    }, comboUser.token);
    assert.strictEqual(putRes.status, 403);
  });

  test('6. Revoke share: Revoked user immediately receives 403 and task disappears from shared list', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 6 Revoke ${runId}`,
      status: 'todo'
    }, creator.token);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    // Chia sẻ cho viewer
    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [viewer.id],
      permission: 'viewer'
    }, creator.token);

    // Viewer kiểm tra thấy task trong /tasks?scope=shared
    const beforeList = await reqApi('GET', '/api/tasks?scope=shared', null, viewer.token);
    assert.strictEqual(beforeList.status, 200);
    assert.ok(beforeList.body.tasks.some(t => t.id === taskId));

    // Lấy ID bản ghi share
    const sharesRes = await reqApi('GET', `/api/tasks/${taskId}/shares`, null, creator.token);
    const viewerShare = sharesRes.body.shares.find(s => s.user.id === viewer.id);
    assert.ok(viewerShare, 'Viewer share must exist');

    // Creator thu hồi share
    const delShareRes = await reqApi('DELETE', `/api/tasks/${taskId}/shares/${viewerShare.id}`, null, creator.token);
    assert.strictEqual(delShareRes.status, 200);

    // Viewer truy cập task -> 403 Forbidden
    const afterDetail = await reqApi('GET', `/api/tasks/${taskId}`, null, viewer.token);
    assert.strictEqual(afterDetail.status, 403);

    // Task biến mất khỏi danh sách chia sẻ
    const afterList = await reqApi('GET', '/api/tasks?scope=shared', null, viewer.token);
    assert.strictEqual(afterList.status, 200);
    assert.strictEqual(afterList.body.tasks.some(t => t.id === taskId), false);
  });

  test('7. POST /api/email-logs/:id/retry: Only Creator of task allowed, non-creator receives 403', async () => {
    const taskRes = await reqApi('POST', '/api/tasks', {
      title: `[TEST] Perm Task 7 Retry ${runId}`,
      status: 'todo'
    }, creator.token);
    const taskId = taskRes.body.task.id;
    createdTaskIds.push(taskId);

    // Tạo bản ghi EmailLog thất bại gắn với task này
    const failedLog = await EmailLog.create({
      taskId,
      recipientEmail: assignee.email,
      eventType: 'task_assigned',
      subject: '[TEST] Assigned Email',
      status: 'failed',
      attempts: 1,
      errorMessage: 'Mock SMTP failed'
    });

    // Editor gọi retry -> 403
    const eRetry = await reqApi('POST', `/api/email-logs/${failedLog._id}/retry`, null, editor.token);
    assert.strictEqual(eRetry.status, 403);

    // Assignee gọi retry -> 403
    const aRetry = await reqApi('POST', `/api/email-logs/${failedLog._id}/retry`, null, assignee.token);
    assert.strictEqual(aRetry.status, 403);

    // Viewer gọi retry -> 403
    const vRetry = await reqApi('POST', `/api/email-logs/${failedLog._id}/retry`, null, viewer.token);
    assert.strictEqual(vRetry.status, 403);

    // Stranger gọi retry -> 403
    const sRetry = await reqApi('POST', `/api/email-logs/${failedLog._id}/retry`, null, stranger.token);
    assert.strictEqual(sRetry.status, 403);

    // Creator gọi retry -> 200 (vì SMTP mock rỗng nên trả về failed nhưng request được phép thực thi)
    const cRetry = await reqApi('POST', `/api/email-logs/${failedLog._id}/retry`, null, creator.token);
    assert.strictEqual(cRetry.status, 200);
    assert.strictEqual(cRetry.body.emailLog.attempts, 2);
  });
});
