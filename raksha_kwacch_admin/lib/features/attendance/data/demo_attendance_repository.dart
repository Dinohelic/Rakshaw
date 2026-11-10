import '../domain/attendance_models.dart';
import '../domain/attendance_repository.dart';

/// In-memory implementation of [AttendanceRepository] for demonstration,
/// unit testing, and interactive simulator evaluation.
class DemoAttendanceRepository implements AttendanceRepository {
  static DemoAttendanceRepository? _sharedInstance;

  /// Global session instance ensuring simulation state survives route navigation.
  static DemoAttendanceRepository get shared =>
      _sharedInstance ??= DemoAttendanceRepository();

  /// Reset the singleton instance for testing environments.
  static void resetShared() {
    _sharedInstance = null;
  }

  // Pre-seeded virtual RFID card assignments linked to demo students
  final List<RfidCard> _cards = [
    RfidCard(
      uid: 'CARD-RFID-001',
      studentId: 's1', // Aarav Sharma (Approved, Active, RT-A, BUS-14)
      issuedAt: DateTime(2026, 9, 1),
    ),
    RfidCard(
      uid: 'CARD-RFID-002',
      studentId: 's2', // Priya Patel (Approved, Active, RT-B, BUS-22)
      issuedAt: DateTime(2026, 9, 1),
    ),
    RfidCard(
      uid: 'CARD-RFID-003',
      studentId: 's3', // Rahul Kumar (Pending Approval, RT-A, BUS-14)
      issuedAt: DateTime(2026, 9, 2),
    ),
    RfidCard(
      uid: 'CARD-RFID-004',
      studentId: 's4', // Ananya Gupta (Approved, Active, RT-C, BUS-19)
      issuedAt: DateTime(2026, 9, 2),
    ),
    RfidCard(
      uid: 'CARD-RFID-005',
      studentId: 's5', // Vikram Singh (Approved, Suspended Transport, BUS-22)
      issuedAt: DateTime(2026, 9, 3),
    ),
    RfidCard(
      uid: 'CARD-RFID-009',
      studentId: 's9', // Rohan Mehta (Rejected Approval, BUS-19)
      issuedAt: DateTime(2026, 9, 4),
    ),
  ];

  // In-memory occupancy cache
  final Map<String, StudentBusOccupancy> _occupancy = {};

  // In-memory event ledger
  final List<RfidScanEvent> _events = [];

  DemoAttendanceRepository() {
    _seedInitialData();
  }

  void _seedInitialData() {
    _events.clear();
    _occupancy.clear();

    final now = DateTime.now().toUtc();

    // Initial baseline events (earlier today)
    _events.addAll([
      RfidScanEvent(
        id: 'EVT-INIT-101',
        rfidUid: 'CARD-RFID-004',
        studentId: 's4',
        studentName: 'Ananya Gupta',
        enrollmentNumber: 'SGTU-2024-CSE-088',
        busCode: 'BUS-19',
        routeCode: 'RT-C',
        deviceId: 'DEMO-ESP32-01',
        type: RfidEventType.boarding,
        status: RfidEventStatus.processed,
        timestamp: now.subtract(const Duration(minutes: 42)),
        conflictReason: null,
        isSimulated: true,
        source: 'DEMO_SIMULATOR',
      ),
      RfidScanEvent(
        id: 'EVT-INIT-102',
        rfidUid: 'CARD-RFID-004',
        studentId: 's4',
        studentName: 'Ananya Gupta',
        enrollmentNumber: 'SGTU-2024-CSE-088',
        busCode: 'BUS-19',
        routeCode: 'RT-C',
        deviceId: 'DEMO-ESP32-01',
        type: RfidEventType.deboarding,
        status: RfidEventStatus.processed,
        timestamp: now.subtract(const Duration(minutes: 15)),
        conflictReason: null,
        isSimulated: true,
        source: 'DEMO_SIMULATOR',
      ),
      RfidScanEvent(
        id: 'EVT-INIT-103',
        rfidUid: 'CARD-UNKNOWN-999',
        busCode: 'BUS-14',
        routeCode: 'RT-A',
        deviceId: 'DEMO-ESP32-01',
        type: RfidEventType.flagged,
        status: RfidEventStatus.flaggedPendingReview,
        timestamp: now.subtract(const Duration(minutes: 8)),
        conflictReason:
            'Unknown or unregistered RFID Card UID (CARD-UNKNOWN-999).',
        isSimulated: true,
        source: 'DEMO_SIMULATOR',
      ),
    ]);
  }

  @override
  Future<List<RfidCard>> getAssignedCards() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_cards);
  }

  @override
  Future<RfidCard?> getCardByUid(String uid) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _cards.indexWhere(
      (c) => c.uid.toLowerCase() == uid.trim().toLowerCase(),
    );
    if (index == -1) return null;
    return _cards[index];
  }

  @override
  Future<RfidCard?> getCardForStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _cards.indexWhere((c) => c.studentId == studentId);
    if (index == -1) return null;
    return _cards[index];
  }

  @override
  Future<StudentBusOccupancy> getStudentOccupancy(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _occupancy[studentId] ?? StudentBusOccupancy.initial(studentId);
  }

  @override
  Future<List<RfidScanEvent>> getRecentEvents({int limit = 50}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_events.take(limit));
  }

  @override
  Future<List<RfidScanEvent>> getFlaggedEvents() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(
      _events.where((e) => e.type == RfidEventType.flagged),
    );
  }

  @override
  Future<List<RfidScanEvent>> getValidBoardingEvents() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(
      _events.where(
        (e) =>
            e.type == RfidEventType.boarding ||
            e.type == RfidEventType.deboarding,
      ),
    );
  }

  @override
  Future<void> saveEvent(RfidScanEvent event) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _events.insert(0, event);
  }

  @override
  Future<void> updateOccupancy(StudentBusOccupancy occupancy) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _occupancy[occupancy.studentId] = occupancy;
  }

  @override
  Future<void> resetSimulation() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _seedInitialData();
  }
}
