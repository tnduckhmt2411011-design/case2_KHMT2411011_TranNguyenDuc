const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const { getTaskPermissions } = require('../services/taskService');

/**
 * Middleware kiem tra quyen thuc hien hanh dong tren cong viec
 * Nhap vao ten hanh dong: 'view' | 'edit' | 'changeStatus' | 'delete' | 'assign' | 'share'
 * Kiem tra id sai (400), khong tim thay (404), khong du quyen (403)
 * Gan req.task, req.taskPermissions, req.taskShare cho cac xu ly tiep theo
 */
const requireTaskPermission = (action) => {
  return async (req, res, next) => {
    try {
      const taskId = req.params.id || req.params.taskId;

      // 1. Kiem tra dinh dang ID
      if (!taskId || !mongoose.Types.ObjectId.isValid(taskId)) {
        return res.status(400).json({ message: 'ID cong viec khong hop le' });
      }

      // 2. Nap cong viec tu database
      const task = await Task.findById(taskId);
      if (!task) {
        return res.status(404).json({ message: 'Khong tim thay cong viec' });
      }

      // 3. Nap thong tin share cua nguoi dung neu co
      const userId = req.user._id;
      const share = await TaskShare.findOne({ taskId: task._id, userId });

      // 4. Tinh toan ma tran quyen tap trung qua getTaskPermissions
      const permissions = getTaskPermissions(task, userId, share);

      const actionKeyMap = {
        view: 'canView',
        edit: 'canEdit',
        changeStatus: 'canChangeStatus',
        delete: 'canDelete',
        assign: 'canAssign',
        share: 'canShare'
      };

      const requiredPermissionKey = actionKeyMap[action];
      if (!requiredPermissionKey || !permissions[requiredPermissionKey]) {
        if (action === 'view') {
          return res.status(403).json({ message: 'Ban khong co quyen truy cap cong viec nay' });
        }
        return res.status(403).json({ message: 'Ban khong co quyen thuc hien hanh dong nay' });
      }

      // 5. Gan vao req de cac middleware va controller sau su dung
      req.task = task;
      req.taskPermissions = permissions;
      req.taskShare = share;

      next();
    } catch (error) {
      next(error);
    }
  };
};

module.exports = requireTaskPermission;
