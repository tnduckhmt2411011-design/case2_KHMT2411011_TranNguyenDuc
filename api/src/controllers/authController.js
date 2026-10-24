const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { validateRegisterInput } = require('../validators/authValidator');

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

module.exports = {
  register
};
