import 'package:flutter_test/flutter_test.dart';
import 'package:nursaflow/features/home/models/study_stats.dart';

StudyLogEntry _entry(int minutes, DateTime loggedAt) =>
    StudyLogEntry(id: 'x', minutes: minutes, loggedAt: loggedAt);

void main() {
  group('minutesLoggedOn', () {
    test('sums only entries on the given day', () {
      final day = DateTime(2026, 1, 10);
      final entries = [
        _entry(20, DateTime(2026, 1, 10, 8, 0)),
        _entry(15, DateTime(2026, 1, 10, 21, 30)),
        _entry(999, DateTime(2026, 1, 11)), // different day — must be excluded
      ];

      expect(minutesLoggedOn(entries, day), 35);
    });

    test('returns 0 when nothing was logged that day', () {
      final entries = [_entry(30, DateTime(2026, 1, 9))];
      expect(minutesLoggedOn(entries, DateTime(2026, 1, 10)), 0);
    });
  });

  group('minutesLoggedBetween', () {
    test('includes the start boundary and excludes the end boundary', () {
      final start = DateTime(2026, 1, 1);
      final endExclusive = DateTime(2026, 1, 8);
      final entries = [
        _entry(10, DateTime(2026, 1, 1, 0, 0)), // exactly at start — included
        _entry(20, DateTime(2026, 1, 5)), // inside range
        _entry(30, DateTime(2026, 1, 8, 0, 0)), // exactly at end — excluded
        _entry(40, DateTime(2025, 12, 31)), // before range — excluded
      ];

      expect(minutesLoggedBetween(entries, start, endExclusive), 30);
    });
  });

  group('computeStreak', () {
    test('is 0 for no entries', () {
      expect(computeStreak([]), 0);
    });

    test('counts today when today has an entry', () {
      final today = DateTime.now();
      final entries = [
        _entry(10, today),
        _entry(10, today.subtract(const Duration(days: 1))),
        _entry(10, today.subtract(const Duration(days: 2))),
      ];
      expect(computeStreak(entries), 3);
    });

    test('still counts through yesterday if today has no entry yet', () {
      final today = DateTime.now();
      final entries = [
        _entry(10, today.subtract(const Duration(days: 1))),
        _entry(10, today.subtract(const Duration(days: 2))),
      ];
      // Student hasn't logged today yet, but the streak shouldn't zero out
      // before they've had the chance to.
      expect(computeStreak(entries), 2);
    });

    test('resets to 0 if the most recent entry was more than a day ago', () {
      final today = DateTime.now();
      final entries = [_entry(10, today.subtract(const Duration(days: 3)))];
      expect(computeStreak(entries), 0);
    });

    test('stops counting at the first gap day', () {
      final today = DateTime.now();
      final entries = [
        _entry(10, today),
        _entry(10, today.subtract(const Duration(days: 1))),
        // day 2 missing — gap
        _entry(10, today.subtract(const Duration(days: 3))),
      ];
      expect(computeStreak(entries), 2);
    });
  });
}