String fmtDuration(int s) {
  if (s <= 0) return '';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

String fmtViews(int n) {
  if (n <= 0) return '';
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B views';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M views';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K views';
  return '$n views';
}

String friendlyError(Object e) {
  final t = e.toString();
  if (t.contains('SocketException') || t.contains('Failed host lookup') || t.contains('ClientException')) {
    return 'Internet connection check karo aur dobara try karo.';
  }
  if (t.contains('TimeoutException')) {
    return 'Server ne time par jawab nahi diya. Dobara try karo.';
  }
  final clean = t.replaceFirst('Exception: ', '');
  final short = clean.length > 180 ? '${clean.substring(0, 180)}...' : clean;
  return 'Video load nahi hui.\n$short';
}
