const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');
const requireTaskPermission = require('../middleware/permissionMiddleware');

// Tat ca cac route tasks deu yeu cau token
router.use(authMiddleware);

router.get('/', taskController.getTasks);
router.get('/:id', requireTaskPermission('view'), taskController.getTaskById);

module.exports = router;
