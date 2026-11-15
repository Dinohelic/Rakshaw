import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/student/models/phone_location.dart';

void main() {
  group('PhoneLocation Model Tests', () {
    test('Serializes to and from JSON correctly', () {
      final json = {
        'student_id': 'stu-001',
        'latitude': 28.4595,
        'longitude': 76.9266,
        'accuracy_m': 12.5,
        'recorded_at': '2026-11-15T12:00:00.000Z',
        'phone_device_id': 'CPH2665',
        'updated_at': '2026-11-15T12:00:05.000Z',
      };

      final location = PhoneLocation.fromJson(json);

      expect(location.studentId, 'stu-001');
      expect(location.latitude, 28.4595);
      expect(location.longitude, 76.9266);
      expect(location.accuracyM, 12.5);
      expect(location.phoneDeviceId, 'CPH2665');
      expect(location.recordedAt, DateTime.parse('2026-11-15T12:00:00.000Z'));

      final encoded = location.toJson();
      expect(encoded['student_id'], 'stu-001');
      expect(encoded['latitude'], 28.4595);
      expect(encoded['longitude'], 76.9266);
      expect(encoded['accuracy_m'], 12.5);
      expect(encoded['phone_device_id'], 'CPH2665');
    });

    test('Freshness: isStale is false when age <= 300 seconds, true when > 300 seconds', () {
      final fresh = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 10.0,
        recordedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 120)),
      );
      expect(fresh.isStale, isFalse);

      final stale = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 10.0,
        recordedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 305)),
      );
      expect(stale.isStale, isTrue);
    });

    test('Accuracy: isAccurate is true when accuracy <= 100m, false when > 100m', () {
      final accurate = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 25.0,
        recordedAt: DateTime.now().toUtc(),
      );
      expect(accurate.isAccurate, isTrue);

      final inaccurate = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 120.0,
        recordedAt: DateTime.now().toUtc(),
      );
      expect(inaccurate.isAccurate, isFalse);
    });

    test('formattedRecordedTimeIst converts UTC to IST (+05:30) with 12-hour format', () {
      // 06:30:00 UTC -> 12:00:00 PM IST
      final loc1 = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 10.0,
        recordedAt: DateTime.parse('2026-11-15T06:30:00.000Z'),
      );
      expect(loc1.formattedRecordedTimeIst, '12:00:00 PM IST');

      // 18:30:00 UTC -> 12:00:00 AM IST (midnight)
      final loc2 = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 10.0,
        recordedAt: DateTime.parse('2026-11-15T18:30:00.000Z'),
      );
      expect(loc2.formattedRecordedTimeIst, '12:00:00 AM IST');
    });

    test('formattedAccuracy formats accuracy with 1 decimal place', () {
      final loc = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: 8.46,
        recordedAt: DateTime.now().toUtc(),
      );
      expect(loc.formattedAccuracy, '±8.5 m');

      final unknown = PhoneLocation(
        studentId: 'stu-001',
        latitude: 28.4595,
        longitude: 76.9266,
        accuracyM: null,
        recordedAt: DateTime.now().toUtc(),
      );
      expect(unknown.formattedAccuracy, 'Unknown');
    });
  });
}

