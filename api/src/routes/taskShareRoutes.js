const express = require('express');
const router = express.Router({ mergeParams: true });
const taskShareController = require('../controllers/taskShareController');
const requireTaskPermission = require('../middleware/permissionMiddleware');

router.get('/', requireTaskPermission('view'), taskShareController.getShares);
router.post('/', requireTaskPermission('share'), taskShareController.createShares);
router.patch('/:shareId', requireTaskPermission('share'), taskShareController.updateShare);
router.delete('/:shareId', requireTaskPermission('share'), taskShareController.deleteShare);

module.exports = router;
