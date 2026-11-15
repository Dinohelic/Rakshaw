import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/phone_location.dart';
import 'location_repository.dart';

class SupabaseLocationRepository implements LocationRepository {
  final SupabaseClient? client;

  SupabaseLocationRepository({this.client});

  SupabaseClient get _effectiveClient {
    final c = client;
    if (c != null) return c;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const LocationAuthException(
        'Supabase client is not initialized. Please verify configuration.',
      );
    }
  }

  @override
  Future<PhoneLocation?> getPhoneLocation(String studentId) async {
    final clientInstance = _effectiveClient;
    final user = clientInstance.auth.currentUser;
    if (user == null) {
      throw const LocationAuthException('User is not authenticated.');
    }

    try {
      final response = await clientInstance
          .from('student_phone_locations')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      if (response == null) return null;
      return PhoneLocation.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw LocationDataException('Database error: ${e.message} (${e.code})');
    } catch (e) {
      if (e is LocationException) rethrow;
      throw LocationDataException('Failed to retrieve phone location: ${e.toString()}');
    }
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
    final clientInstance = _effectiveClient;
    final user = clientInstance.auth.currentUser;
    if (user == null) {
      throw const LocationAuthException('User is not authenticated.');
    }

    try {
      final nowUtc = (recordedAt ?? DateTime.now()).toUtc();
      final payload = {
        'student_id': studentId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'recorded_at': nowUtc.toIso8601String(),
        'phone_device_id': phoneDeviceId ?? 'Android-Device',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await clientInstance
          .from('student_phone_locations')
          .upsert(payload, onConflict: 'student_id')
          .select()
          .single();

      return PhoneLocation.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw LocationDataException('Database error: ${e.message} (${e.code})');
    } catch (e) {
      if (e is LocationException) rethrow;
      throw LocationDataException('Failed to publish phone location: ${e.toString()}');
    }
  }
}

