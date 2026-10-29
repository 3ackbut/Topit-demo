import 'package:flutter_test/flutter_test.dart';
import 'package:topit_flutter/services/notification_service.dart';

void main() {
  test('次回通知日時はUTCの次の日付境界になる', () {
    final next = NotificationService.nextUtcMidnight(
      DateTime.utc(2026, 7, 12, 8, 59),
    );

    expect(next, DateTime.utc(2026, 7, 13));
    expect(next.isUtc, isTrue);
  });

  test('ローカル時刻を渡してもUTCの日付で計算する', () {
    final next = NotificationService.nextUtcMidnight(
      DateTime.parse('2026-07-12T23:30:00+09:00'),
    );

    expect(next, DateTime.utc(2026, 7, 13));
  });
}
