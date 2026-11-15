import 'package:raksha_kawach_app/features/student/models/phone_location.dart';
import 'package:raksha_kawach_app/features/student/repositories/location_repository.dart';

class MockLocationRepository implements LocationRepository {
  PhoneLocation? storedLocation;
  bool shouldFail;
  int upsertCallCount = 0;
  String? lastUpsertedStudentId;

  MockLocationRepository({
    this.storedLocation,
    this.shouldFail = false,
  });

  @override
  Future<PhoneLocation?> getPhoneLocation(String studentId) async {
    if (shouldFail) throw const LocationDataException('Network error fetching location');
    return storedLocation;
  }

  @override
  Future<PhoneLocation> upsertPhoneLocation({
    required String studentId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    String? phoneDeviceId,
    DateTime? recordedAt,
  }) async {
    upsertCallCount++;
    lastUpsertedStudentId = studentId;

    if (shouldFail) {
      throw const LocationDataException('Network timeout writing to Supabase');
    }

    final location = PhoneLocation(
      studentId: studentId,
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      recordedAt: recordedAt ?? DateTime.now(),
      phoneDeviceId: phoneDeviceId,
      updatedAt: DateTime.now(),
    );
    storedLocation = location;
    return location;
  }
}

