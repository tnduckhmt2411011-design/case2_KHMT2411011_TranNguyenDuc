const express = require('express');
const router = express.Router();
const emailLogController = require('../controllers/emailLogController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.post('/:id/retry', emailLogController.retryEmailLogById);

module.exports = router;
