import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';

void main() {
  group('StudentProfile Model Tests', () {
    test('Masks RFID card correctly', () {
      const student1 = StudentProfile(
        id: '1',
        studentCode: 'STU001',
        studentName: 'Arvind',
        rfidUid: '04A1B2C3',
      );
      // Clean string length is 8; last 4 characters are B2C3
      expect(student1.maskedRfid, '••• B2C3');

      const studentNoCard = StudentProfile(
        id: '2',
        studentCode: 'STU002',
        studentName: 'Manish',
        rfidUid: null,
      );
      expect(studentNoCard.maskedRfid, 'No Card Linked');

      const studentShortCard = StudentProfile(
        id: '3',
        studentCode: 'STU003',
        studentName: 'Deepak',
        rfidUid: '4A',
      );
      expect(studentShortCard.maskedRfid, '••• 4A');
    });

    test('Evaluates strike status labels and card blocking', () {
      const student0 = StudentProfile(
        id: '1',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 0,
        isBlocked: false,
      );
      expect(student0.strikeStatusLabel, '0/3 — Active');
      expect(student0.isCardBlocked, isFalse);

      const student1 = StudentProfile(
        id: '1',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 1,
        isBlocked: false,
      );
      expect(student1.strikeStatusLabel, '1/3 — Warning');
      expect(student1.isCardBlocked, isFalse);

      const student2 = StudentProfile(
        id: '1',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 2,
        isBlocked: false,
      );
      expect(student2.strikeStatusLabel, '2/3 — Final Warning');
      expect(student2.isCardBlocked, isFalse);

      const student3 = StudentProfile(
        id: '2',
        studentCode: 'STU002',
        studentName: 'Manish',
        activeStrikes: 3,
        isBlocked: true,
        blockedReason: 'Three confirmed proxy violations',
      );
      expect(student3.strikeStatusLabel, '3/3 — Card Blocked');
      expect(student3.isCardBlocked, isTrue);
    });

    test('Parses from Supabase JSON accurately', () {
      final json = {
        'id': 'a1b2c3d4-0000-0000-0000-000000000001',
        'student_code': 'STU001',
        'student_name': 'Arvind',
        'rfid_uid': '04A1B2C3',
        'active_strikes': 1,
        'is_blocked': false,
        'strike_cycle': 1,
        'route_code': 'Route 1 (SGT Campus)',
        'bus_code': 'BUS-01',
        'blocked_at': null,
        'blocked_reason': null,
      };

      final profile = StudentProfile.fromJson(json);
      expect(profile.id, 'a1b2c3d4-0000-0000-0000-000000000001');
      expect(profile.studentCode, 'STU001');
      expect(profile.studentName, 'Arvind');
      expect(profile.activeStrikes, 1);
      expect(profile.isBlocked, isFalse);
      expect(profile.routeCode, 'Route 1 (SGT Campus)');
    });
  });
}

