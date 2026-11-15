import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kawach_app/features/student/models/student_profile.dart';

void main() {
  group('StudentProfile Model Tests — All Four Registered Students', () {
    test('STU001 — Arvind profile properties', () {
      final p = StudentProfile(
        id: '3bf3d2fa-3cb4-4dc1-97fb-2f99230aed98',
        studentCode: 'STU001',
        studentName: 'Arvind',
        rfidUid: '1ACB6525',
        activeStrikes: 0,
        isBlocked: false,
      );

      expect(p.studentName, 'Arvind');
      expect(p.studentCode, 'STU001');
      expect(p.maskedRfid, '••• 6525');
      expect(p.isCardBlocked, false);
      expect(p.strikeStatusLabel, '0/3 — Active');
      expect(p.displayRoute, 'Not Assigned');
      expect(p.displayBus, 'Not Assigned');
    });

    test('STU002 — Manish profile properties', () {
      final p = StudentProfile(
        id: 'f7c3c8c7-331e-4008-aa17-0b0a65e43fbf',
        studentCode: 'STU002',
        studentName: 'Manish',
        rfidUid: 'BA52A824',
        activeStrikes: 0,
        isBlocked: false,
      );

      expect(p.studentName, 'Manish');
      expect(p.studentCode, 'STU002');
      expect(p.maskedRfid, '••• A824');
      expect(p.isCardBlocked, false);
      expect(p.strikeStatusLabel, '0/3 — Active');
    });

    test('STU003 — Deepak profile properties', () {
      final p = StudentProfile(
        id: 'b2b06d04-e5af-4f1c-8f0e-f2363b0d652f',
        studentCode: 'STU003',
        studentName: 'Deepak',
        rfidUid: 'FA8CB4E3',
        activeStrikes: 0,
        isBlocked: false,
      );

      expect(p.studentName, 'Deepak');
      expect(p.studentCode, 'STU003');
      expect(p.maskedRfid, '••• B4E3');
      expect(p.isCardBlocked, false);
      expect(p.strikeStatusLabel, '0/3 — Active');
    });

    test('STU004 — Ankit profile properties', () {
      final p = StudentProfile(
        id: '4e7fec45-7a89-438a-9ed8-4a2408790c18',
        studentCode: 'STU004',
        studentName: 'Ankit',
        rfidUid: '6ADF2825',
        activeStrikes: 0,
        isBlocked: false,
      );

      expect(p.studentName, 'Ankit');
      expect(p.studentCode, 'STU004');
      expect(p.maskedRfid, '••• 2825');
      expect(p.isCardBlocked, false);
      expect(p.strikeStatusLabel, '0/3 — Active');
    });

    test('Card blocking logic correctly handles 3-strike disciplinary threshold', () {
      final strike1 = StudentProfile(
        id: 's1',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 1,
      );
      expect(strike1.isCardBlocked, false);
      expect(strike1.strikeStatusLabel, '1/3 — Warning');

      final strike2 = StudentProfile(
        id: 's2',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 2,
      );
      expect(strike2.isCardBlocked, false);
      expect(strike2.strikeStatusLabel, '2/3 — Final Warning');

      final strike3 = StudentProfile(
        id: 's3',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 3,
      );
      expect(strike3.isCardBlocked, true);
      expect(strike3.strikeStatusLabel, '3/3 — Card Blocked');
    });

    test('Administrative isBlocked flag blocks transport card regardless of strike count', () {
      final adminBlocked = StudentProfile(
        id: 's4',
        studentCode: 'STU001',
        studentName: 'Arvind',
        activeStrikes: 0,
        isBlocked: true,
        blockedReason: 'Under review by Dean of Students',
      );
      expect(adminBlocked.isCardBlocked, true);
      expect(adminBlocked.strikeStatusLabel, '3/3 — Card Blocked');
      expect(adminBlocked.blockedReason, 'Under review by Dean of Students');
    });

    test('Masked RFID handles null, empty, and short card numbers safely', () {
      const pNull = StudentProfile(
        id: '1',
        studentCode: 'S',
        studentName: 'N',
        rfidUid: null,
      );
      expect(pNull.maskedRfid, 'No Card Linked');

      const pEmpty = StudentProfile(
        id: '2',
        studentCode: 'S',
        studentName: 'N',
        rfidUid: '   ',
      );
      expect(pEmpty.maskedRfid, 'No Card Linked');

      const pShort = StudentProfile(
        id: '3',
        studentCode: 'S',
        studentName: 'N',
        rfidUid: 'AB',
      );
      expect(pShort.maskedRfid, '••• AB');
    });

    test('Assigned route and bus display exact values when present in Supabase', () {
      const pWithRoute = StudentProfile(
        id: '1',
        studentCode: 'S',
        studentName: 'N',
        routeCode: 'Route 42 (Delhi Metro)',
        busCode: 'BUS-108',
      );
      expect(pWithRoute.displayRoute, 'Route 42 (Delhi Metro)');
      expect(pWithRoute.displayBus, 'BUS-108');
    });
  });
}

