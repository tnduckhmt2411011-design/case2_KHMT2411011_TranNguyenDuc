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
const Notification = require('../src/models/Notification');
const EmailLog = require('../src/models/EmailLog');

describe('Statistics Integration Tests (E1)', () => {
  let server;
  let port;
  let user1Token;
  let user2Token;
  let emptyUserToken;
  const createdUserIds = [];
  const createdTaskIds = [];

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

    const u1 = await registerAndLogin('Stats User 1', `test+stats_u1_${Date.now()}@example.test`);
    const u2 = await registerAndLogin('Stats User 2', `test+stats_u2_${Date.now()}@example.test`);
    const uEmpty = await registerAndLogin('Stats Empty', `test+stats_empty_${Date.now()}@example.test`);

    user1Token = u1.token;
    user2Token = u2.token;
    emptyUserToken = uEmpty.token;

    const now = Date.now();

    // Task 1: todo, high, due in 1 day (dueSoon)
    const t1 = await reqApi('POST', '/api/tasks', {
      title: '[TEST] Task 1 High Due Soon',
      priority: 'high',
      status: 'todo',
      dueDate: new Date(now + 86400000).toISOString()
    }, user1Token);
    createdTaskIds.push(t1.body.task.id);

    // Task 2: in_progress, medium, due 2 days ago (overdue)
    const t2 = await reqApi('POST', '/api/tasks', {
      title: '[TEST] Task 2 Medium Overdue',
      priority: 'medium',
      status: 'in_progress',
      dueDate: new Date(now - 172800000).toISOString()
    }, user1Token);
    createdTaskIds.push(t2.body.task.id);

    // Task 3: completed, low, due 2 days ago (completed, so NOT overdue)
    const t3 = await reqApi('POST', '/api/tasks', {
      title: '[TEST] Task 3 Low Completed Overdue',
      priority: 'low',
      status: 'completed',
      dueDate: new Date(now - 172800000).toISOString()
    }, user1Token);
    createdTaskIds.push(t3.body.task.id);

    // Task 4: todo, medium, due in 5 days (dueSoon only if days >= 5)
    const t4 = await reqApi('POST', '/api/tasks', {
      title: '[TEST] Task 4 Medium Due 5 Days',
      priority: 'medium',
      status: 'todo',
      dueDate: new Date(now + 432000000).toISOString()
    }, user1Token);
    createdTaskIds.push(t4.body.task.id);

    // Assign Task 1 to User 2
    await reqApi('POST', `/api/tasks/${t1.body.task.id}/assignees`, {
      userIds: [u2.id],
      primaryAssigneeId: u2.id
    }, user1Token);

    // Share Task 4 with User 2
    await reqApi('POST', `/api/tasks/${t4.body.task.id}/shares`, {
      userIds: [u2.id],
      permission: 'viewer'
    }, user1Token);
  });

  after(async () => {
    for (const tId of createdTaskIds) {
      await Task.deleteMany({ _id: tId });
      await TaskShare.deleteMany({ taskId: tId });
      await Notification.deleteMany({ taskId: tId });
      await EmailLog.deleteMany({ taskId: tId });
    }
    if (createdUserIds.length > 0) {
      await User.deleteMany({ _id: { $in: createdUserIds } });
    }
    await server.close();
    await mongoose.disconnect();
  });

  test('1. Tra ve 401 khi khong co token', async () => {
    const res1 = await reqApi('GET', '/api/statistics/tasks');
    assert.strictEqual(res1.status, 401);

    const res2 = await reqApi('GET', '/api/statistics/assignments');
    assert.strictEqual(res2.status, 401);

    const res3 = await reqApi('GET', '/api/statistics/deadlines');
    assert.strictEqual(res3.status, 401);
  });

  test('2. Nguoi chua co cong viec nhan toan so 0', async () => {
    const rTasks = await reqApi('GET', '/api/statistics/tasks', null, emptyUserToken);
    assert.strictEqual(rTasks.status, 200);
    assert.strictEqual(rTasks.body.total, 0);
    assert.strictEqual(rTasks.body.byStatus.todo, 0);
    assert.strictEqual(rTasks.body.byStatus.in_progress, 0);
    assert.strictEqual(rTasks.body.byStatus.completed, 0);
    assert.strictEqual(rTasks.body.byPriority.low, 0);
    assert.strictEqual(rTasks.body.byPriority.medium, 0);
    assert.strictEqual(rTasks.body.byPriority.high, 0);

    const rAssign = await reqApi('GET', '/api/statistics/assignments', null, emptyUserToken);
    assert.strictEqual(rAssign.status, 200);
    assert.strictEqual(rAssign.body.totalAssigned, 0);
    assert.strictEqual(rAssign.body.totalPrimary, 0);

    const rDeadlines = await reqApi('GET', '/api/statistics/deadlines', null, emptyUserToken);
    assert.strictEqual(rDeadlines.status, 200);
    assert.strictEqual(rDeadlines.body.overdueCount, 0);
    assert.strictEqual(rDeadlines.body.upcomingCount, 0);
  });

  test('3. Thong ke tasks khop so lieu User 1', async () => {
    const res = await reqApi('GET', '/api/statistics/tasks', null, user1Token);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.total, 4);
    assert.strictEqual(res.body.byStatus.todo, 2);
    assert.strictEqual(res.body.byStatus.in_progress, 1);
    assert.strictEqual(res.body.byStatus.completed, 1);
    assert.strictEqual(res.body.byPriority.high, 1);
    assert.strictEqual(res.body.byPriority.medium, 2);
    assert.strictEqual(res.body.byPriority.low, 1);
  });

  test('4. Thong ke assignments khop so lieu User 2', async () => {
    const res = await reqApi('GET', '/api/statistics/assignments', null, user2Token);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.totalAssigned, 1);
    assert.strictEqual(res.body.totalPrimary, 1);
    assert.strictEqual(res.body.assignedByStatus.todo, 1);
    assert.strictEqual(res.body.primaryByStatus.todo, 1);
  });

  test('5. Thong ke phan quyen: User 2 chi thay 2 cong viec duoc giao hoac chia se', async () => {
    const res = await reqApi('GET', '/api/statistics/tasks', null, user2Token);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.total, 2);
    assert.strictEqual(res.body.byStatus.todo, 2);
  });

  test('6. Thong ke deadlines: overdue khong tinh task completed, dueSoon tinh theo days', async () => {
    // Mac dinh days = 3
    const resDefault = await reqApi('GET', '/api/statistics/deadlines', null, user1Token);
    assert.strictEqual(resDefault.status, 200);
    assert.strictEqual(resDefault.body.overdueCount, 1); // Task 2, not Task 3
    assert.strictEqual(resDefault.body.overdue[0].title, '[TEST] Task 2 Medium Overdue');
    assert.strictEqual(resDefault.body.upcomingCount, 1); // Task 1 only (in 1 day, Task 4 is in 5 days)

    // With days = 7
    const res7 = await reqApi('GET', '/api/statistics/deadlines?days=7', null, user1Token);
    assert.strictEqual(res7.status, 200);
    assert.strictEqual(res7.body.days, 7);
    assert.strictEqual(res7.body.upcomingCount, 2); // Task 1 and Task 4

    // Validations: days ngoai 1 den 30 tra 400
    const res0 = await reqApi('GET', '/api/statistics/deadlines?days=0', null, user1Token);
    assert.strictEqual(res0.status, 400);

    const res35 = await reqApi('GET', '/api/statistics/deadlines?days=35', null, user1Token);
    assert.strictEqual(res35.status, 400);

    const resInvalid = await reqApi('GET', '/api/statistics/deadlines?days=abc', null, user1Token);
    assert.strictEqual(resInvalid.status, 400);

    // Danh sach toi da 10 muc
    assert.ok(resDefault.body.overdue.length <= 10);
    assert.ok(resDefault.body.upcoming.length <= 10);
  });
});
