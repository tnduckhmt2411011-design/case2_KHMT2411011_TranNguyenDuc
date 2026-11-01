/**
 * Middleware xac thuc du lieu dau vao su dung cac ham validator
 * @param {Function} validatorFn - Ham kiem tra tra ve { isValid, errors, data }
 */
const validate = (validatorFn) => {
  return (req, res, next) => {
    const { isValid, errors, data } = validatorFn(req.body);
    if (!isValid) {
      return res.status(400).json({ message: errors[0] });
    }
    // Gan du lieu da duoc lam sach va xac thuc vao req.validatedBody
    req.validatedBody = data;
    next();
  };
};

module.exports = validate;
