import 'package:flutter_test/flutter_test.dart';
import 'package:yosakoi_countdown/countdown.dart';

void main() {
  final at = DateTime(2026, 10, 5, 0, 5);
  final gathering = Gathering(at: at, team: '鳴子連', venue: '中央公園');
  test('残り分数は切り上げ、日付をまたいでも計算する', () {
    expect(gathering.remainingMinutes(DateTime(2026, 10, 4, 23, 55)), 10);
    expect(
      gathering.remainingMinutes(at.subtract(const Duration(seconds: 61))),
      2,
    );
    expect(
      gathering.remainingMinutes(at.subtract(const Duration(seconds: 1))),
      1,
    );
    expect(gathering.remainingMinutes(at), 0);
    expect(gathering.remainingMinutes(at.add(const Duration(hours: 1))), 0);
  });
  test('集合直前と集合後の表示', () {
    expect(
      gathering.status(at.subtract(const Duration(seconds: 60))),
      'まもなく集合です',
    );
    expect(
      gathering.status(at.subtract(const Duration(minutes: 10))),
      '集合場所へ向かいましょう',
    );
    expect(gathering.glassText(at), contains('集合時刻になりました'));
    expect(gathering.glassText(at), contains('中央公園'));
  });
}
