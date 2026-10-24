// Middleware xu ly loi tap trung
const errorMiddleware = (err, req, res, next) => {
  const statusCode = err.statusCode || (res.statusCode && res.statusCode !== 200 ? res.statusCode : 500);

  if (statusCode === 500) {
    console.error('Loi may chu noi bo:', err);
    return res.status(500).json({
      message: 'Loi may chu noi bo. Vui long thu lai sau.'
    });
  }

  return res.status(statusCode).json({
    message: err.message || 'Da xay ra loi khong xac dinh.'
  });
};

module.exports = errorMiddleware;
