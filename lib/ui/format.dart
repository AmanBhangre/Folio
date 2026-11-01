// Sizes and times as the replica shows them ("231 MB", "2 hours ago").

String formatSize(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  if (mb < 0.1) return '${(bytes / 1024).ceil()} KB';
  return mb < 10 ? '${mb.toStringAsFixed(1)} MB' : '${mb.round()} MB';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatWhen(DateTime? t, {DateTime? now}) {
  if (t == null) return 'Never';
  now ??= DateTime.now();
  final d = now.difference(t);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return d.inMinutes == 1 ? '1 minute ago' : '${d.inMinutes} minutes ago';
  if (d.inHours < 24 && t.day == now.day) return d.inHours == 1 ? '1 hour ago' : '${d.inHours} hours ago';
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final yesterday = now.subtract(const Duration(days: 1));
  if (t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day) return 'Yesterday, $hm';
  return '${_months[t.month - 1]} ${t.day}${t.year != now.year ? ', ${t.year}' : ''}';
}
