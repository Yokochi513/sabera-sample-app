class Gathering {
  const Gathering({required this.at, this.team = '', this.venue = ''});
  final DateTime at;
  final String team;
  final String venue;
  int remainingMinutes(DateTime now) {
    final ms = at.difference(now).inMilliseconds;
    return ms > 0 ? (ms / 60000).ceil() : 0;
  }

  String status(DateTime now) {
    final ms = at.difference(now).inMilliseconds;
    if (ms <= 0) return '集合時刻になりました';
    if (ms <= 60000) return 'まもなく集合です';
    if (ms <= 600000) return '集合場所へ向かいましょう';
    return '演舞に向けて、ゆっくり準備を';
  }

  String glassText(DateTime now) => [
    'よさこい 演舞集合',
    if (team.isNotEmpty) team,
    at.isAfter(now) ? '集合まで あと${remainingMinutes(now)}分' : '集合時刻になりました',
    '${at.month}/${at.day} ${clock(at)} 集合',
    if (venue.isNotEmpty) venue,
  ].join('\n');
}

String clock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
