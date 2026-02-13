String formatRelativeTime(String dateTimeString) {
  DateTime time;
  try {
    time = DateTime.parse(dateTimeString).toLocal();
  } catch (_) {
    return dateTimeString;
  }

  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) {
    return '방금전';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}분 전';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}시간 전';
  }

  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');

  return '$y. $m. $d';

  // final isPm = time.hour >= 12;
  // final h12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  // final hour = h12.toString().padLeft(2, '0');
  // final minute = time.minute.toString().padLeft(2, '0');
  // final meridiem = isPm ? 'PM' : 'AM';

  // return '$y. $m. $d $meridiem $hour:$minute';
}
