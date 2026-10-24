const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI);
    console.log(`Ket noi MongoDB thanh cong: ${conn.connection.name}`);
  } catch (error) {
    console.error(`Loi ket noi MongoDB: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
