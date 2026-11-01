const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const emailLogController = require('../controllers/emailLogController');
const assignmentRoutes = require('./assignmentRoutes');
const taskShareRoutes = require('./taskShareRoutes');
const authMiddleware = require('../middleware/authMiddleware');
const requireTaskPermission = require('../middleware/permissionMiddleware');
const validate = require('../middleware/validateMiddleware');
const {
  validateTaskCreateInput,
  validateTaskUpdateInput,
  validateTaskStatusInput
} = require('../validators/taskValidator');

// Tat ca cac route tasks deu yeu cau token
router.use(authMiddleware);

router.get('/', taskController.getTasks);
router.post('/', validate(validateTaskCreateInput), taskController.createTask);
router.get('/:id', requireTaskPermission('view'), taskController.getTaskById);
router.put('/:id', requireTaskPermission('edit'), validate(validateTaskUpdateInput), taskController.updateTask);
router.patch('/:id/status', requireTaskPermission('changeStatus'), validate(validateTaskStatusInput), taskController.updateTaskStatus);
router.delete('/:id', requireTaskPermission('delete'), taskController.deleteTask);
router.get('/:id/email-logs', requireTaskPermission('view'), emailLogController.getTaskEmailLogs);
router.get('/:id/activities', requireTaskPermission('view'), taskController.getTaskActivities);

// Sub-routes giao viec va chia se
router.use('/:id/assignees', assignmentRoutes);
router.use('/:id/shares', taskShareRoutes);

module.exports = router;
