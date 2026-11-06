const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const mongoose = require('mongoose');
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

process.env.SMTP_HOST = '';
process.env.SMTP_USER = '';
process.env.SMTP_PASS = '';

const app = require('../src/app');
const User = require('../src/models/User');
const Task = require('../src/models/Task');
const TaskShare = require('../src/models/TaskShare');
const TaskActivity = require('../src/models/TaskActivity');
const Notification = require('../src/models/Notification');
const EmailLog = require('../src/models/EmailLog');

describe('Task Activities Integration Tests (E2)', () => {
  let server;
  let port;
  let creatorToken;
  let strangerToken;
  let assigneeId;
  let taskId;
  const createdUserIds = [];

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
    }, res => {
      let d = '';
      res.on('data', chunk => d += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(d) });
        } catch {
          resolve({ status: res.statusCode, raw: d });
        }
      });
    });
    req.on('error', reject);
    if (sBody) req.write(sBody);
    req.end();
  });

  before(async () => {
    await mongoose.connect(process.env.MONGODB_URI);
    server = http.createServer(app);
    await new Promise(r => server.listen(0, r));
    port = server.address().port;

    const registerAndLogin = async (prefix, email) => {
      await reqApi('POST', '/api/auth/register', {
        fullName: `[TEST] ${prefix}`,
        email,
        password: 'password123'
      });
      const res = await reqApi('POST', '/api/auth/login', {
        email,
        password: 'password123'
      });
      createdUserIds.push(res.body.user.id);
      return { id: res.body.user.id, token: res.body.token };
    };

    const creator = await registerAndLogin('Activity Creator', `test+act_creator_${Date.now()}@example.test`);
    const assignee = await registerAndLogin('Activity Assignee', `test+act_assignee_${Date.now()}@example.test`);
    const stranger = await registerAndLogin('Activity Stranger', `test+act_stranger_${Date.now()}@example.test`);

    creatorToken = creator.token;
    strangerToken = stranger.token;
    assigneeId = assignee.id;

    // 1. Action: created
    const rTask = await reqApi('POST', '/api/tasks', {
      title: '[TEST] Task for Activities',
      description: 'Initial description',
      priority: 'low',
      status: 'todo'
    }, creatorToken);
    taskId = rTask.body.task.id;

    // 2. Action: updated
    await reqApi('PUT', `/api/tasks/${taskId}`, {
      title: '[TEST] Task for Activities (Updated)',
      description: 'Updated description',
      priority: 'medium',
      status: 'todo'
    }, creatorToken);

    // 3. Action: status_changed
    await reqApi('PATCH', `/api/tasks/${taskId}/status`, {
      status: 'in_progress'
    }, creatorToken);

    // 4. Action: assigned
    await reqApi('POST', `/api/tasks/${taskId}/assignees`, {
      userIds: [assigneeId],
      primaryAssigneeId: assigneeId
    }, creatorToken);

    // 5. Action: shared
    await reqApi('POST', `/api/tasks/${taskId}/shares`, {
      userIds: [assigneeId],
      permission: 'editor'
    }, creatorToken);
  });

  after(async () => {
    if (taskId) {
      await Task.deleteMany({ _id: taskId });
      await TaskShare.deleteMany({ taskId });
      await TaskActivity.deleteMany({ taskId });
      await Notification.deleteMany({ taskId });
      await EmailLog.deleteMany({ taskId });
    }
    if (createdUserIds.length > 0) {
      await User.deleteMany({ _id: { $in: createdUserIds } });
    }
    await server.close();
    await mongoose.disconnect();
  });

  test('1. Lay lich su hoat dong thanh cong va co du cac hanh dong', async () => {
    const res = await reqApi('GET', `/api/tasks/${taskId}/activities`, null, creatorToken);
    assert.strictEqual(res.status, 200);
    assert.ok(Array.isArray(res.body.activities));
    assert.ok(res.body.activities.length >= 5);

    const actions = res.body.activities.map(a => a.action);
    assert.ok(actions.includes('created'), 'Phai co action created');
    assert.ok(actions.includes('updated'), 'Phai co action updated');
    assert.ok(actions.includes('status_changed'), 'Phai co action status_changed');
    assert.ok(actions.includes('assigned'), 'Phai co action assigned');
    assert.ok(actions.includes('shared'), 'Phai co action shared');
  });

  test('2. Thu tu hoat dong phai la moi nhat truoc (createdAt desc)', async () => {
    const res = await reqApi('GET', `/api/tasks/${taskId}/activities`, null, creatorToken);
    assert.strictEqual(res.status, 200);
    const activities = res.body.activities;

    for (let i = 0; i < activities.length - 1; i++) {
      const current = new Date(activities[i].createdAt).getTime();
      const next = new Date(activities[i + 1].createdAt).getTime();
      assert.ok(current >= next, `Hoat dong thu ${i} phai moi hon hoac bang hoat dong ${i+1}`);
    }
  });

  test('3. Nguoi la bi 403 khi xem lich su hoat dong', async () => {
    const res = await reqApi('GET', `/api/tasks/${taskId}/activities`, null, strangerToken);
    assert.strictEqual(res.status, 403);
    assert.ok(res.body.message);
  });

  test('4. ID khong hop le tra ve 400, khong ton tai tra ve 404', async () => {
    const rBad = await reqApi('GET', '/api/tasks/invalid-id/activities', null, creatorToken);
    assert.strictEqual(rBad.status, 400);

    const rNotFound = await reqApi('GET', '/api/tasks/507f1f77bcf86cd799439011/activities', null, creatorToken);
    assert.strictEqual(rNotFound.status, 404);
  });
});
