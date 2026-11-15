import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';

void main() {
  group('AttendanceRecord Model Tests', () {
    final sampleJson = {
      'id': '5c432308-27a6-480d-8ed8-2b489d28ca28',
      'student_id': '3bf3d2fa-3cb4-4dc1-97fb-2f99230aed98',
      'attendance_status': 'present',
      'scanned_at': '2026-11-14T12:02:14.259+00:00',
      'latitude': 28.4595,
      'longitude': 77.0266,
      'device_id': 'raksha-esp32s3-01',
      'created_at': '2026-11-14T12:02:14.259+00:00',
      'event_type': 'morning_boarding',
      'event_date': '2026-11-14',
      'verification_status': 'phone_present',
      'phone_distance_m': 14.2,
      'phone_location_at': '2026-11-14T12:02:10.000+00:00',
      'phone_location_age_seconds': 4,
      'phone_accuracy_m': 5.0,
      'adjudicated_outcome': null,
    };

    test('Parses from JSON correctly', () {
      final record = AttendanceRecord.fromJson(sampleJson);

      expect(record.id, '5c432308-27a6-480d-8ed8-2b489d28ca28');
      expect(record.studentId, '3bf3d2fa-3cb4-4dc1-97fb-2f99230aed98');
      expect(record.attendanceStatus, 'present');
      expect(record.deviceId, 'raksha-esp32s3-01');
      expect(record.eventType, 'morning_boarding');
      expect(record.eventDate, '2026-11-14');
      expect(record.verificationStatus, 'phone_present');
      expect(record.phoneDistanceM, 14.2);
    });

    test('Converts UTC timestamp to 12-hour IST format with AM/PM', () {
      // 12:02 UTC = 17:32 IST (5:32 PM)
      final record = AttendanceRecord.fromJson(sampleJson);

      expect(record.formattedTimeIst, '05:32 PM');
      expect(record.formattedDateIst, '14 Nov 2026');
      expect(record.formattedDateTimeIst, '14 Nov 2026, 05:32 PM IST');
      expect(record.istDateKey, '2026-11-14');
    });

    test('Correctly handles morning AM times in IST', () {
      // 03:15 UTC = 08:45 IST (8:45 AM)
      final amRecord = AttendanceRecord(
        id: 'rec-am',
        studentId: 'stu-1',
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-15T03:15:00.000Z'),
      );

      expect(amRecord.formattedTimeIst, '08:45 AM');
      expect(amRecord.formattedDateIst, '15 Nov 2026');
      expect(amRecord.istDateKey, '2026-11-15');
    });

    test('Correctly handles midnight 12 AM edge case in IST', () {
      // 18:30 UTC = 00:00 IST next day (12:00 AM)
      final midnightRecord = AttendanceRecord(
        id: 'rec-mid',
        studentId: 'stu-1',
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T18:30:00.000Z'),
      );

      expect(midnightRecord.formattedTimeIst, '12:00 AM');
      expect(midnightRecord.formattedDateIst, '15 Nov 2026');
    });

    test('Correctly handles noon 12 PM edge case in IST', () {
      // 06:30 UTC = 12:00 IST (12:00 PM)
      final noonRecord = AttendanceRecord(
        id: 'rec-noon',
        studentId: 'stu-1',
        attendanceStatus: 'present',
        scannedAt: DateTime.parse('2026-11-14T06:30:00.000Z'),
      );

      expect(noonRecord.formattedTimeIst, '12:00 PM');
    });

    test('Verification status mapping adheres strictly to specifications', () {
      // 1. phone_present -> Phone Verified
      final r1 = AttendanceRecord(
        id: '1',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        verificationStatus: 'phone_present',
      );
      expect(r1.verificationType, VerificationStatusType.phonePresent);
      expect(r1.verificationStatusLabel, 'Phone Verified');
      expect(r1.verificationBadgeColor, Colors.greenAccent);
      expect(r1.verificationIcon, Icons.check_circle_outline);
      expect(r1.effectiveOutcomeLabel, 'Present • Verified Proximity');

      // 2. phone_not_nearby -> Phone Not Nearby
      final r2 = AttendanceRecord(
        id: '2',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        verificationStatus: 'phone_not_nearby',
      );
      expect(r2.verificationType, VerificationStatusType.phoneNotNearby);
      expect(r2.verificationStatusLabel, 'Phone Not Nearby');
      expect(r2.verificationBadgeColor, Colors.orangeAccent);
      expect(r2.verificationIcon, Icons.warning_amber_rounded);
      expect(r2.effectiveOutcomeLabel, 'Present • GPS Mismatch (Flagged)');

      // 3. location_unavailable -> Phone Location Unavailable
      final r3 = AttendanceRecord(
        id: '3',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        verificationStatus: 'location_unavailable',
      );
      expect(r3.verificationType, VerificationStatusType.locationUnavailable);
      expect(r3.verificationStatusLabel, 'Phone Location Unavailable');
      expect(r3.verificationBadgeColor, Colors.amberAccent);
      expect(r3.verificationIcon, Icons.location_off_outlined);
      expect(r3.effectiveOutcomeLabel, 'Present • Location Unavailable');

      // 4. verification_uncertain -> Verification Uncertain
      final r4 = AttendanceRecord(
        id: '4',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        verificationStatus: 'verification_uncertain',
      );
      expect(r4.verificationType, VerificationStatusType.verificationUncertain);
      expect(r4.verificationStatusLabel, 'Verification Uncertain');
      expect(r4.verificationBadgeColor, Colors.lightBlueAccent);
      expect(r4.verificationIcon, Icons.help_outline);
      expect(r4.effectiveOutcomeLabel, 'Present • Uncertain Proximity');

      // 5. unknown / null
      final r5 = AttendanceRecord(
        id: '5',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        verificationStatus: null,
      );
      expect(r5.verificationType, VerificationStatusType.unknown);
      expect(r5.verificationStatusLabel, 'Pending Verification');
    });

    test('Event type mapping handles all supported boarding events', () {
      final m = AttendanceRecord(
        id: '1',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        eventType: 'morning_boarding',
      );
      expect(m.eventTypeLabel, 'Morning Boarding');
      expect(m.eventIcon, Icons.wb_sunny_outlined);

      final e = AttendanceRecord(
        id: '2',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        eventType: 'evening_boarding',
      );
      expect(e.eventTypeLabel, 'Evening Boarding');
      expect(e.eventIcon, Icons.nights_stay_outlined);

      final d = AttendanceRecord(
        id: '3',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        eventType: 'deboarding',
      );
      expect(d.eventTypeLabel, 'Deboarding');
      expect(d.eventIcon, Icons.directions_walk_outlined);
    });

    test('Adjudicated outcome overrides effective outcome when present', () {
      final r = AttendanceRecord(
        id: '1',
        studentId: 's',
        attendanceStatus: 'present',
        scannedAt: DateTime.now(),
        verificationStatus: 'phone_not_nearby',
        adjudicatedOutcome: 'Legitimate Exemption Approved',
      );

      expect(r.effectiveOutcomeLabel, 'Adjudicated: Legitimate Exemption Approved');
    });
  });
}

