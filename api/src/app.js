const express = require('express');
const authRoutes = require('./routes/authRoutes');
const errorMiddleware = require('./middleware/errorMiddleware');

const app = express();

// Middleware phan tich cu phap JSON
app.use(express.json());

// Endpoint kiem tra trang thai he thong
app.get('/', (req, res) => {
  res.json({ message: 'Task Manager API dang hoat dong' });
});

// Routes
app.use('/api/auth', authRoutes);

// Middleware xu ly loi
app.use(errorMiddleware);

module.exports = app;
