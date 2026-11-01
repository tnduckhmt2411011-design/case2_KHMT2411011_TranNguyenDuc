/**
 * Kiem tra du lieu dau vao cho tao moi cong viec
 * Quy dinh:
 * - title: bat buoc, trim, toi da 200 ky tu
 * - description: tuy chon, string
 * - priority: tuy chon, thuoc low|medium|high (mac dinh medium)
 * - status: tuy chon, thuoc todo|in_progress|completed (mac dinh todo)
 * - startDate, dueDate: ngay hop le; neu co ca hai thi dueDate >= startDate
 * - Cac truong khac bi bo qua
 */
const validateTaskCreateInput = (data = {}) => {
  const errors = [];

  // 1. Title
  const title = typeof data.title === 'string' ? data.title.trim() : '';
  if (!title) {
    errors.push('Tieu de cong viec la bat buoc');
  } else if (title.length > 200) {
    errors.push('Tieu de cong viec khong duoc vuot qua 200 ky tu');
  }

  // 2. Description
  const description = typeof data.description === 'string' ? data.description.trim() : '';

  // 3. Priority
  const allowedPriorities = ['low', 'medium', 'high'];
  let priority = 'medium';
  if (data.priority !== undefined && data.priority !== null) {
    if (!allowedPriorities.includes(data.priority)) {
      errors.push('Muc do uu tien khong hop le (low, medium, high)');
    } else {
      priority = data.priority;
    }
  }

  // 4. Status
  const allowedStatuses = ['todo', 'in_progress', 'completed'];
  let status = 'todo';
  if (data.status !== undefined && data.status !== null) {
    if (!allowedStatuses.includes(data.status)) {
      errors.push('Trang thai khong hop le (todo, in_progress, completed)');
    } else {
      status = data.status;
    }
  }

  // 5. Dates
  let startDate = null;
  if (data.startDate) {
    const parsedStart = new Date(data.startDate);
    if (isNaN(parsedStart.getTime())) {
      errors.push('Ngay bat dau khong hop le');
    } else {
      startDate = parsedStart;
    }
  }

  let dueDate = null;
  if (data.dueDate) {
    const parsedDue = new Date(data.dueDate);
    if (isNaN(parsedDue.getTime())) {
      errors.push('Han hoan thanh khong hop le');
    } else {
      dueDate = parsedDue;
    }
  }

  if (startDate && dueDate && dueDate < startDate) {
    errors.push('Han hoan thanh phai lon hon hoac bang ngay bat dau');
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: {
      title,
      description,
      priority,
      status,
      startDate,
      dueDate
    }
  };
};

/**
 * Kiem tra du lieu dau vao cho cap nhat cong viec (PUT)
 * Chi nhan title, description, startDate, dueDate, priority, status
 */
const validateTaskUpdateInput = (data = {}) => {
  const errors = [];

  // Title la bat buoc khi PUT
  const title = typeof data.title === 'string' ? data.title.trim() : '';
  if (!title) {
    errors.push('Tieu de cong viec la bat buoc');
  } else if (title.length > 200) {
    errors.push('Tieu de cong viec khong duoc vuot qua 200 ky tu');
  }

  const description = typeof data.description === 'string' ? data.description.trim() : '';

  const allowedPriorities = ['low', 'medium', 'high'];
  let priority = 'medium';
  if (data.priority !== undefined && data.priority !== null) {
    if (!allowedPriorities.includes(data.priority)) {
      errors.push('Muc do uu tien khong hop le (low, medium, high)');
    } else {
      priority = data.priority;
    }
  }

  const allowedStatuses = ['todo', 'in_progress', 'completed'];
  let status = 'todo';
  if (data.status !== undefined && data.status !== null) {
    if (!allowedStatuses.includes(data.status)) {
      errors.push('Trang thai khong hop le (todo, in_progress, completed)');
    } else {
      status = data.status;
    }
  }

  let startDate = null;
  if (data.startDate) {
    const parsedStart = new Date(data.startDate);
    if (isNaN(parsedStart.getTime())) {
      errors.push('Ngay bat dau khong hop le');
    } else {
      startDate = parsedStart;
    }
  }

  let dueDate = null;
  if (data.dueDate) {
    const parsedDue = new Date(data.dueDate);
    if (isNaN(parsedDue.getTime())) {
      errors.push('Han hoan thanh khong hop le');
    } else {
      dueDate = parsedDue;
    }
  }

  if (startDate && dueDate && dueDate < startDate) {
    errors.push('Han hoan thanh phai lon hon hoac bang ngay bat dau');
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: {
      title,
      description,
      priority,
      status,
      startDate,
      dueDate
    }
  };
};

/**
 * Kiem tra du lieu dau vao khi doi trang thai (PATCH status)
 */
const validateTaskStatusInput = (data = {}) => {
  const errors = [];
  const allowedStatuses = ['todo', 'in_progress', 'completed'];

  if (!data.status || !allowedStatuses.includes(data.status)) {
    errors.push('Trang thai khong hop le (todo, in_progress, completed)');
  }

  return {
    isValid: errors.length === 0,
    errors,
    data: {
      status: data.status
    }
  };
};

module.exports = {
  validateTaskCreateInput,
  validateTaskUpdateInput,
  validateTaskStatusInput
};
