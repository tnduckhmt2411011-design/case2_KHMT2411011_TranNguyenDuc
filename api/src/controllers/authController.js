const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const {
  validateRegisterInput,
  validateLoginInput,
  validateUpdateProfileInput,
  validateChangePasswordInput
} = require('../validators/authValidator');

// POST /api/auth/register
const register = async (req, res, next) => {
  try {
    const { isValid, errors, data } = validateRegisterInput(req.body);
    if (!isValid) {
      return res.status(400).json({ message: errors[0] });
    }

    const { fullName, email, password } = data;

    // Kiem tra email ton tai truoc
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ message: 'Email da duoc su dung' });
    }

    // Bam mat khau bang bcryptjs
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const user = new User({
      fullName,
      email,
      passwordHash
    });

    await user.save();

    // Tra ve 201 kem thong tin nguoi dung (tuyet doi khong tra passwordHash)
    return res.status(201).json({
      message: 'Dang ky thanh cong',
      user: {
        id: user._id.toString(),
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ message: 'Email da duoc su dung' });
    }
    next(error);
  }
};

// POST /api/auth/login
const login = async (req, res, next) => {
  try {
    const { isValid, errors, data } = validateLoginInput(req.body);
    if (!isValid) {
      return res.status(400).json({ message: errors[0] });
    }

    const { email, password } = data;

    // Tim nguoi dung theo email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng' });
    }

    // So khop mat khau
    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng' });
    }

    // Tao JWT token
    const token = jwt.sign(
      { userId: user._id.toString(), email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    return res.status(200).json({
      message: 'Dang nhap thanh cong',
      token,
      user: {
        id: user._id.toString(),
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/auth/me
const getMe = async (req, res, next) => {
  try {
    return res.status(200).json({
      message: 'Thong tin nguoi dung hien tai',
      user: {
        id: req.user._id.toString(),
        fullName: req.user.fullName,
        email: req.user.email,
        avatarUrl: req.user.avatarUrl,
        createdAt: req.user.createdAt,
        updatedAt: req.user.updatedAt
      }
    });
  } catch (error) {
    next(error);
  }
};

// PUT /api/auth/me
const updateProfile = async (req, res, next) => {
  try {
    const { isValid, errors, data } = validateUpdateProfileInput(req.body);
    if (!isValid) {
      return res.status(400).json({ message: errors[0] });
    }

    const user = req.user;
    user.fullName = data.fullName;
    if (data.avatarUrl !== undefined) {
      user.avatarUrl = data.avatarUrl;
    }

    await user.save();

    return res.status(200).json({
      message: 'Cap nhat thong tin ca nhan thanh cong',
      user: {
        id: user._id.toString(),
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
  } catch (error) {
    next(error);
  }
};

// PUT /api/auth/change-password
const changePassword = async (req, res, next) => {
  try {
    const { isValid, errors, data } = validateChangePasswordInput(req.body);
    if (!isValid) {
      return res.status(400).json({ message: errors[0] });
    }

    const user = req.user;
    const isMatch = await bcrypt.compare(data.currentPassword, user.passwordHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Mat khau hien tai khong dung' });
    }

    const salt = await bcrypt.genSalt(10);
    user.passwordHash = await bcrypt.hash(data.newPassword, salt);
    await user.save();

    return res.status(200).json({
      message: 'Doi mat khau thanh cong'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  getMe,
  updateProfile,
  changePassword
};
