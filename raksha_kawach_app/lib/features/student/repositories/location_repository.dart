import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/phone_location.dart';
import 'supabase_location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return SupabaseLocationRepository();
});

abstract class LocationRepository {
  Future<PhoneLocation?> getPhoneLocation(String studentId);

  Future<PhoneLocation> upsertPhoneLocation({
    required String studentId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    String? phoneDeviceId,
    DateTime? recordedAt,
  });
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

class LocationAuthException extends LocationException {
  const LocationAuthException(super.message);
}

class LocationDataException extends LocationException {
  const LocationDataException(super.message);
}
