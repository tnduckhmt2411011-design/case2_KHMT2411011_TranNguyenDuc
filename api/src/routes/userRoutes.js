const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');

// Tat ca cac route users deu yeu cau dang nhap
router.use(authMiddleware);

router.get('/search', userController.searchUsers);
router.get('/:id', userController.getUserById);

module.exports = router;
