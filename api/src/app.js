const express = require('express');
const authRoutes = require('./routes/authRoutes');
const taskRoutes = require('./routes/taskRoutes');
const userRoutes = require('./routes/userRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const statisticsRoutes = require('./routes/statisticsRoutes');
const emailLogRoutes = require('./routes/emailLogRoutes');
const errorMiddleware = require('./middleware/errorMiddleware');

const app = express();

// Middleware phan tich cu phap JSON
app.use(express.json());

// Dam bao req.body luon la object, tranh loi 500 khi request thieu body
// hoac khong gui Content-Type: application/json
app.use((req, res, next) => {
  if (!req.body || typeof req.body !== 'object') {
    req.body = {};
  }
  next();
});

// Endpoint kiem tra trang thai he thong
app.get('/', (req, res) => {
  res.json({ message: 'Task Manager API dang hoat dong' });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/users', userRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/statistics', statisticsRoutes);
app.use('/api/email-logs', emailLogRoutes);

// Middleware xu ly loi
app.use(errorMiddleware);

module.exports = app;
