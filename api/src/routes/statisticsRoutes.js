const express = require('express');
const router = express.Router();
const statisticsController = require('../controllers/statisticsController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.get('/tasks', statisticsController.getTaskStatistics);
router.get('/assignments', statisticsController.getAssignmentStatistics);
router.get('/deadlines', statisticsController.getDeadlineStatistics);

module.exports = router;
