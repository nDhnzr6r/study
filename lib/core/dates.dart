const List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

String dateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseDateKey(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String timestamp(DateTime value) => value.toIso8601String();

String weekdayLabel(DateTime value) => '周${_weekdays[value.weekday - 1]}';

String shortWeekdayLabel(DateTime value) => _weekdays[value.weekday - 1];

String monthLabel(DateTime value) => '${value.month} 月';

String monthDayLabel(DateTime value) => '${value.month} 月 ${value.day} 日';

String fullDateLabel(DateTime value) =>
    '${value.year} 年 ${value.month} 月 ${value.day} 日 · ${weekdayLabel(value)}';

String dueLabel(DateTime? due, DateTime today) {
  if (due == null) return '未安排';
  final diff = dateOnly(due).difference(dateOnly(today)).inDays;
  if (diff < 0) return '逾期 ${-diff} 天';
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  return '$diff 天后';
}

String intervalLabel(int days) {
  if (days <= 0) return '今天';
  if (days == 1) return '明天';
  return '$days 天后';
}

String percentLabel(double ratio) => '${(ratio * 100).round()}%';
