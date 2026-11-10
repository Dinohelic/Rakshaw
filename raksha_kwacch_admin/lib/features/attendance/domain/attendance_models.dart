/// Types of RFID scan events.
enum RfidEventType {
  boarding,
  deboarding,
  flagged;

  String get displayName {
    switch (this) {
      case RfidEventType.boarding:
        return 'Boarding';
      case RfidEventType.deboarding:
        return 'Deboarding';
      case RfidEventType.flagged:
        return 'Flagged';
    }
  }
}

/// Status of an RFID event for operational review.
enum RfidEventStatus { processed, flaggedPendingReview }

/// Domain model representing a virtual or physical RFID card assignment.
class RfidCard {
  final String uid;
  final String studentId;
  final bool isActive;
  final DateTime issuedAt;

  const RfidCard({
    required this.uid,
    required this.studentId,
    this.isActive = true,
    required this.issuedAt,
  });

  RfidCard copyWith({
    String? uid,
    String? studentId,
    bool? isActive,
    DateTime? issuedAt,
  }) {
    return RfidCard(
      uid: uid ?? this.uid,
      studentId: studentId ?? this.studentId,
      isActive: isActive ?? this.isActive,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }
}

/// Tracks the active transit occupancy of a student across the fleet.
class StudentBusOccupancy {
  final String studentId;
  final bool isOnBus;
  final String? busCode;
  final String? lastEventId;
  final DateTime? lastEventTime;

  const StudentBusOccupancy({
    required this.studentId,
    required this.isOnBus,
    this.busCode,
    this.lastEventId,
    this.lastEventTime,
  });

  factory StudentBusOccupancy.initial(String studentId) {
    return StudentBusOccupancy(studentId: studentId, isOnBus: false);
  }

  StudentBusOccupancy copyWith({
    bool? isOnBus,
    String? busCode,
    String? lastEventId,
    DateTime? lastEventTime,
    bool clearBus = false,
  }) {
    return StudentBusOccupancy(
      studentId: studentId,
      isOnBus: isOnBus ?? this.isOnBus,
      busCode: clearBus ? null : (busCode ?? this.busCode),
      lastEventId: lastEventId ?? this.lastEventId,
      lastEventTime: lastEventTime ?? this.lastEventTime,
    );
  }
}

/// Represents a discrete RFID scan event recorded at a bus terminal/scanner.
class RfidScanEvent {
  final String id;
  final String rfidUid;
  final String? studentId;
  final String? studentName;
  final String? enrollmentNumber;
  final String busCode;
  final String routeCode;
  final String deviceId;
  final RfidEventType type;
  final RfidEventStatus status;
  final DateTime timestamp; // Stored in UTC internally
  final String? conflictReason;
  final bool isSimulated;
  final String source;

  const RfidScanEvent({
    required this.id,
    required this.rfidUid,
    this.studentId,
    this.studentName,
    this.enrollmentNumber,
    required this.busCode,
    required this.routeCode,
    required this.deviceId,
    required this.type,
    required this.status,
    required this.timestamp,
    this.conflictReason,
    this.isSimulated = true,
    this.source = 'DEMO_SIMULATOR',
  });

  RfidScanEvent copyWith({
    String? id,
    String? rfidUid,
    String? studentId,
    String? studentName,
    String? enrollmentNumber,
    String? busCode,
    String? routeCode,
    String? deviceId,
    RfidEventType? type,
    RfidEventStatus? status,
    DateTime? timestamp,
    String? conflictReason,
    bool? isSimulated,
    String? source,
  }) {
    return RfidScanEvent(
      id: id ?? this.id,
      rfidUid: rfidUid ?? this.rfidUid,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      enrollmentNumber: enrollmentNumber ?? this.enrollmentNumber,
      busCode: busCode ?? this.busCode,
      routeCode: routeCode ?? this.routeCode,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      conflictReason: conflictReason ?? this.conflictReason,
      isSimulated: isSimulated ?? this.isSimulated,
      source: source ?? this.source,
    );
  }
}

/// Input payload submitted when simulating or ingesting an RFID scan.
class RfidScanRequest {
  final String rfidUid;
  final String busCode;
  final String routeCode;
  final String deviceId;
  final DateTime? timestamp;
  final bool forceDuplicate;
  final bool isSimulated;

  const RfidScanRequest({
    required this.rfidUid,
    required this.busCode,
    required this.routeCode,
    this.deviceId = 'DEMO-ESP32-01',
    this.timestamp,
    this.forceDuplicate = false,
    this.isSimulated = true,
  });
}
