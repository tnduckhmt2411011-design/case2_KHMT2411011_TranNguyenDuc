const validateRegisterInput = (data) => {
  const errors = [];
  const fullName = typeof data.fullName === 'string' ? data.fullName.trim() : '';
  const email = typeof data.email === 'string' ? data.email.trim().toLowerCase() : '';
  const password = typeof data.password === 'string' ? data.password : '';

  if (!fullName) {
    errors.push('Ho va ten khong duoc de trong');
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email)) {
    errors.push('Email khong hop le');
  }

  if (!password || password.length < 6) {
    errors.push('Mat khau phai co it nhat 6 ky tu');
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: { fullName, email, password }
  };
};

const validateLoginInput = (data) => {
  const errors = [];
  const email = typeof data.email === 'string' ? data.email.trim().toLowerCase() : '';
  const password = typeof data.password === 'string' ? data.password : '';

  if (!email) {
    errors.push('Vui long nhap email');
  }

  if (!password) {
    errors.push('Vui long nhap mat khau');
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: { email, password }
  };
};

const validateUpdateProfileInput = (data = {}) => {
  const errors = [];

  const fullName = typeof data.fullName === 'string' ? data.fullName.trim() : '';
  if (!fullName) {
    errors.push('Ho va ten khong duoc de trong');
  } else if (fullName.length > 100) {
    errors.push('Ho va ten khong duoc vuot qua 100 ky tu');
  }

  let avatarUrl;
  if (Object.prototype.hasOwnProperty.call(data, 'avatarUrl')) {
    avatarUrl = typeof data.avatarUrl === 'string' ? data.avatarUrl.trim() : '';
    if (avatarUrl.length > 500) {
      errors.push('Duong dan anh dai dien khong duoc vuot qua 500 ky tu');
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: { fullName, avatarUrl }
  };
};

const validateChangePasswordInput = (data = {}) => {
  const errors = [];
  const currentPassword = typeof data.currentPassword === 'string'
    ? data.currentPassword
    : '';
  const newPassword = typeof data.newPassword === 'string'
    ? data.newPassword
    : '';

  if (!currentPassword) {
    errors.push('Vui long nhap mat khau hien tai');
  }

  if (!newPassword) {
    errors.push('Vui long nhap mat khau moi');
  } else if (newPassword.length < 6) {
    errors.push('Mat khau moi phai co it nhat 6 ky tu');
  } else if (currentPassword && newPassword === currentPassword) {
    errors.push('Mat khau moi phai khac mat khau hien tai');
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: { currentPassword, newPassword }
  };
};

module.exports = {
  validateRegisterInput,
  validateLoginInput,
  validateUpdateProfileInput,
  validateChangePasswordInput
};
