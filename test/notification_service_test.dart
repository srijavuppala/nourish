import 'package:flutter_test/flutter_test.dart';
import 'package:nourish/features/notifications/notification_service.dart';

void main() {
  group('Reminder.parse', () {
    test('reads a valid HH:mm', () {
      final reminder = Reminder.parse('07:45', defaultMorning);
      expect(reminder.hour, 7);
      expect(reminder.minute, 45);
    });

    test('falls back on malformed input rather than throwing', () {
      expect(Reminder.parse(null, defaultMorning).formatted, '08:00');
      expect(Reminder.parse('nonsense', defaultMorning).formatted, '08:00');
      expect(Reminder.parse('25:00', defaultMorning).formatted, '08:00');
      expect(Reminder.parse('10:70', defaultMorning).formatted, '08:00');
    });

    test('formats back with zero padding', () {
      expect(const Reminder(8, 5).formatted, '08:05');
    });
  });

  group('suggestFrom', () {
    test('suggests an hour after training and an hour after the last meal', () {
      final suggested = NotificationService.suggestFrom(
        gymTime: '06:30',
        mealTimes: ['08:00', '13:00', '19:00'],
      );
      expect(suggested.morning.formatted, '07:30');
      expect(suggested.evening.formatted, '20:00');
    });

    test('falls back to 8am and 8pm when the quiz was skipped', () {
      final suggested = NotificationService.suggestFrom();
      expect(suggested.morning.formatted, '08:00');
      expect(suggested.evening.formatted, '20:00');
    });

    test('wraps past midnight rather than producing hour 24', () {
      final suggested = NotificationService.suggestFrom(
        gymTime: '23:30',
        mealTimes: ['23:00'],
      );
      expect(suggested.morning.formatted, '00:30');
      expect(suggested.evening.formatted, '00:00');
    });
  });
}
