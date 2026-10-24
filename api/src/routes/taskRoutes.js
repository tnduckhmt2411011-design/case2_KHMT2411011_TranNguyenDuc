const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');

// Tat ca cac route tasks deu yeu cau token
router.use(authMiddleware);

router.get('/', taskController.getTasks);

module.exports = router;
