import '../../people/domain/people_models.dart';
import '../../people/domain/people_repository.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';

/// Shared, UI-agnostic event-processing service for RFID boarding transactions.
///
/// Implements the domain validation pipeline:
/// `RFID Scan Input → UID Lookup → Student Eligibility → Boarding State → Event Result`
///
/// Designed to be shared between the Flutter Admin Portal Simulator and future
/// backend ESP32-S3 hardware ingestion endpoints.
class RfidProcessingService {
  final PeopleRepository peopleRepository;
  final AttendanceRepository attendanceRepository;

  // Counter to guarantee absolute uniqueness across high-frequency calls
  static int _eventSequence = 1000;

  RfidProcessingService({
    required this.peopleRepository,
    required this.attendanceRepository,
  });

  /// Processes an RFID tap according to university transport rules.
  Future<RfidScanEvent> processScan(RfidScanRequest request) async {
    final now = request.timestamp?.toUtc() ?? DateTime.now().toUtc();
    _eventSequence++;
    final eventId = 'EVT-${now.millisecondsSinceEpoch}-$_eventSequence';
    final trimmedUid = request.rfidUid.trim();

    // 1. Resolve RFID Card Assignment
    final card = await attendanceRepository.getCardByUid(trimmedUid);
    if (card == null || !card.isActive) {
      final flaggedEvent = RfidScanEvent(
        id: eventId,
        rfidUid: trimmedUid,
        busCode: request.busCode,
        routeCode: request.routeCode,
        deviceId: request.deviceId,
        type: RfidEventType.flagged,
        status: RfidEventStatus.flaggedPendingReview,
        timestamp: now,
        conflictReason: card == null
            ? 'Unknown or unregistered RFID Card UID ($trimmedUid).'
            : 'Inactive RFID Card UID ($trimmedUid). Card is disabled.',
        isSimulated: request.isSimulated,
        source: 'DEMO_SIMULATOR',
      );
      await attendanceRepository.saveEvent(flaggedEvent);
      return flaggedEvent;
    }

    // 2. Resolve Student Record
    final student = await peopleRepository.getStudentById(card.studentId);
    if (student == null) {
      final flaggedEvent = RfidScanEvent(
        id: eventId,
        rfidUid: trimmedUid,
        studentId: card.studentId,
        busCode: request.busCode,
        routeCode: request.routeCode,
        deviceId: request.deviceId,
        type: RfidEventType.flagged,
        status: RfidEventStatus.flaggedPendingReview,
        timestamp: now,
        conflictReason:
            'Associated student profile not found in directory (ID: ${card.studentId}).',
        isSimulated: request.isSimulated,
        source: 'DEMO_SIMULATOR',
      );
      await attendanceRepository.saveEvent(flaggedEvent);
      return flaggedEvent;
    }

    // Helper closure for constructing student-linked conflict events
    RfidScanEvent createStudentConflictEvent(String reason) {
      return RfidScanEvent(
        id: eventId,
        rfidUid: trimmedUid,
        studentId: student.id,
        studentName: student.name,
        enrollmentNumber: student.enrollmentNumber,
        busCode: request.busCode,
        routeCode: request.routeCode,
        deviceId: request.deviceId,
        type: RfidEventType.flagged,
        status: RfidEventStatus.flaggedPendingReview,
        timestamp: now,
        conflictReason: reason,
        isSimulated: request.isSimulated,
        source: 'DEMO_SIMULATOR',
      );
    }

    // 3. Evaluate Registration Approval Status
    if (student.approvalStatus == StudentApprovalStatus.pending) {
      final event = createStudentConflictEvent(
        'Registration is Pending administrative approval. Transit boarding denied.',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    if (student.approvalStatus == StudentApprovalStatus.rejected) {
      final reasonSuffix =
          student.rejectionReason != null && student.rejectionReason!.isNotEmpty
          ? ' (${student.rejectionReason})'
          : '';
      final event = createStudentConflictEvent(
        'Registration is Rejected$reasonSuffix. Transit boarding prohibited.',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    // 4. Evaluate Transport Privilege Status
    if (student.transportStatus == TransportStatus.suspended) {
      final event = createStudentConflictEvent(
        'Student transport privileges are Suspended. Boarding denied.',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    if (student.transportStatus != TransportStatus.active) {
      final event = createStudentConflictEvent(
        'Transport status is ${student.transportStatus.name}. Transit boarding denied.',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    // 5. Evaluate Route & Bus Allocation
    if (student.routeCode.trim().isEmpty || student.busCode.trim().isEmpty) {
      final event = createStudentConflictEvent(
        'Incomplete transport allocation (missing route or bus code).',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    // Assigned Bus Mismatch Check
    if (student.busCode.trim().toUpperCase() !=
        request.busCode.trim().toUpperCase()) {
      final event = createStudentConflictEvent(
        'Assigned bus mismatch: Scanned on ${request.busCode}, but student is allocated to ${student.busCode}.',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    // General Boarding Eligibility Re-check
    if (!student.isBoardingEligible) {
      final event = createStudentConflictEvent(
        'Student failed transit boarding eligibility verification.',
      );
      await attendanceRepository.saveEvent(event);
      return event;
    }

    // 6. Occupancy State Machine Evaluation
    final occupancy = await attendanceRepository.getStudentOccupancy(
      student.id,
    );

    // Intentional Duplicate Check
    if (request.forceDuplicate) {
      final duplicateReason = occupancy.isOnBus
          ? 'Duplicate boarding scan: Student is already marked on board ${occupancy.busCode ?? request.busCode}.'
          : 'Duplicate deboarding scan: Student is not recorded on board any bus.';
      final event = createStudentConflictEvent(duplicateReason);
      await attendanceRepository.saveEvent(event);
      return event;
    }

    // Transition 1: Not On Bus -> Boarding
    if (!occupancy.isOnBus) {
      final boardingEvent = RfidScanEvent(
        id: eventId,
        rfidUid: trimmedUid,
        studentId: student.id,
        studentName: student.name,
        enrollmentNumber: student.enrollmentNumber,
        busCode: request.busCode,
        routeCode: request.routeCode,
        deviceId: request.deviceId,
        type: RfidEventType.boarding,
        status: RfidEventStatus.processed,
        timestamp: now,
        conflictReason: null,
        isSimulated: request.isSimulated,
        source: 'DEMO_SIMULATOR',
      );

      final updatedOccupancy = occupancy.copyWith(
        isOnBus: true,
        busCode: request.busCode,
        lastEventId: eventId,
        lastEventTime: now,
      );

      await attendanceRepository.saveEvent(boardingEvent);
      await attendanceRepository.updateOccupancy(updatedOccupancy);
      return boardingEvent;
    }

    // Transition 2: On Bus -> Deboarding
    final deboardingEvent = RfidScanEvent(
      id: eventId,
      rfidUid: trimmedUid,
      studentId: student.id,
      studentName: student.name,
      enrollmentNumber: student.enrollmentNumber,
      busCode: request.busCode,
      routeCode: request.routeCode,
      deviceId: request.deviceId,
      type: RfidEventType.deboarding,
      status: RfidEventStatus.processed,
      timestamp: now,
      conflictReason: null,
      isSimulated: request.isSimulated,
      source: 'DEMO_SIMULATOR',
    );

    final updatedOccupancy = occupancy.copyWith(
      isOnBus: false,
      clearBus: true,
      lastEventId: eventId,
      lastEventTime: now,
    );

    await attendanceRepository.saveEvent(deboardingEvent);
    await attendanceRepository.updateOccupancy(updatedOccupancy);
    return deboardingEvent;
  }
}
