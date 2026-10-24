const express = require('express');
const errorMiddleware = require('./middleware/errorMiddleware');

const app = express();

// Middleware phan tich cu phap JSON
app.use(express.json());

// Endpoint kiem tra trang thai he thong
app.get('/', (req, res) => {
  res.json({ message: 'Task Manager API dang hoat dong' });
});

// Middleware xu ly loi
app.use(errorMiddleware);

module.exports = app;
