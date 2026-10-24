class DateFormatter {
  static String formatDate(DateTime? date) {
    if (date == null) return 'Chưa thiết lập';
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Chưa thiết lập';
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month/$year';
  }
}
