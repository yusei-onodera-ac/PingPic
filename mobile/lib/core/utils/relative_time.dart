/// "3時間前" / "たった今" style relative timestamp, Instagram-post-caption
/// style. Hand-rolled rather than a package (`timeago` etc.) — the format
/// needed here is small and fixed (Japanese only, a handful of buckets),
/// not worth a dependency for.
String relativeTimeJa(DateTime from) {
  final diff = DateTime.now().difference(from);
  if (diff.inSeconds < 60) return 'たった今';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';
  if (diff.inDays < 7) return '${diff.inDays}日前';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}週間前';
  return '${from.year}/${from.month}/${from.day}';
}
