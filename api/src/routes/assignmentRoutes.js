const express = require('express');
const router = express.Router({ mergeParams: true });
const assignmentController = require('../controllers/assignmentController');
const requireTaskPermission = require('../middleware/permissionMiddleware');

router.get('/', requireTaskPermission('view'), assignmentController.getAssignees);
router.post('/', requireTaskPermission('assign'), assignmentController.assignUsers);
router.patch('/:userId', requireTaskPermission('assign'), assignmentController.setPrimaryAssignee);
router.delete('/:userId', requireTaskPermission('assign'), assignmentController.removeAssignee);

module.exports = router;
