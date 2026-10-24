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

module.exports = {
  validateRegisterInput
};
