const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, 'Ho ten la bat buoc'],
      trim: true
    },
    email: {
      type: String,
      required: [true, 'Email la bat buoc'],
      unique: true,
      lowercase: true,
      trim: true
    },
    passwordHash: {
      type: String,
      required: [true, 'Mat khau la bat buoc']
    },
    avatarUrl: {
      type: String,
      default: ''
    }
  },
  {
    timestamps: true
  }
);

// Loai bo passwordHash khi chuyen doi toJSON hoac toObject
userSchema.methods.toJSON = function () {
  const userObject = this.toObject();
  delete userObject.passwordHash;
  return userObject;
};

const User = mongoose.model('User', userSchema);

module.exports = User;
