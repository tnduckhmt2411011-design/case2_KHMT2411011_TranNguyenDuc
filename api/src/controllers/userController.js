const mongoose = require('mongoose');
const User = require('../models/User');

// Ham thoat cac ky tu dac biet trong chuoi truoc khi dua vao RegExp
const escapeRegex = (string) => {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};

// GET /api/users/search?q=
const searchUsers = async (req, res, next) => {
  try {
    const rawQ = req.query.q || '';
    const q = rawQ.trim();

    if (q.length < 2) {
      return res.status(400).json({ message: 'Tu khoa tim kiem phai co it nhat 2 ky tu' });
    }

    const escapedQ = escapeRegex(q);
    const regex = new RegExp(escapedQ, 'i');

    const users = await User.find({
      $or: [{ fullName: regex }, { email: regex }]
    })
      .select('fullName email avatarUrl')
      .limit(10);

    const formattedUsers = users.map((u) => ({
      id: u._id.toString(),
      fullName: u.fullName,
      email: u.email,
      avatarUrl: u.avatarUrl
    }));

    return res.status(200).json({
      message: 'Tim kiem nguoi dung thanh cong',
      users: formattedUsers
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/users/:id
const getUserById = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'ID nguoi dung khong hop le' });
    }

    const user = await User.findById(id).select('fullName email avatarUrl');
    if (!user) {
      return res.status(404).json({ message: 'Khong tim thay nguoi dung' });
    }

    return res.status(200).json({
      message: 'Lay thong tin nguoi dung thanh cong',
      user: {
        id: user._id.toString(),
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  searchUsers,
  getUserById,
  escapeRegex
};
