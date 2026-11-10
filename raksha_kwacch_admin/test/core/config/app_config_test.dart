import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/core/config/app_config.dart';
import 'package:raksha_kwacch_admin/core/config/supabase_config.dart';
import 'package:raksha_kwacch_admin/core/network/api_endpoints.dart';

void main() {
  group('Centralized Configuration & Endpoints Tests', () {
    test('1. AppConfig provides correct default branding and environment', () {
      expect(AppConfig.appName, equals('Raksha Kawach'));
      expect(AppConfig.appTitle, contains('SGT University Transport Safety'));
      expect(AppConfig.environment, equals('development'));
      expect(AppConfig.isDevelopment, isTrue);
      expect(AppConfig.isProduction, isFalse);
    });

    test(
      '2. SupabaseConfig defaults to confirmed SGT University project URL',
      () {
        expect(
          SupabaseConfig.defaultUrl,
          equals('https://uijvhpfycmhnedccytiq.supabase.co'),
        );
        expect(
          SupabaseConfig.url,
          equals('https://uijvhpfycmhnedccytiq.supabase.co'),
        );
        expect(AppConfig.supabaseUrl, equals(SupabaseConfig.url));
      },
    );

    test('3. SupabaseConfig reports configuration status correctly based on environment', () {
      if (SupabaseConfig.anonKey.isEmpty ||
          SupabaseConfig.anonKey == 'YOUR_PUBLIC_KEY_HERE') {
        expect(SupabaseConfig.isConfigured, isFalse);
        expect(AppConfig.isSupabaseConfigured, isFalse);
      } else {
        expect(SupabaseConfig.isConfigured, isTrue);
        expect(AppConfig.isSupabaseConfigured, isTrue);
      }
    });

    test(
      '4. SupabaseConfig and AppConfig getters reflect consistent state',
      () {
        expect(AppConfig.supabaseUrl, equals(SupabaseConfig.url));
        expect(AppConfig.supabaseAnonKey, equals(SupabaseConfig.anonKey));
        expect(
          AppConfig.isSupabaseConfigured,
          equals(SupabaseConfig.isConfigured),
        );
      },
    );

    test('5. ApiEndpoints centralizes all confirmed Supabase tables and Edge Functions', () {
      // Edge Function
      expect(ApiEndpoints.attendanceFunction, equals('raksha-attendance'));

      // Confirmed database tables
      expect(ApiEndpoints.tableAttendance, equals('attendance'));
      expect(ApiEndpoints.tableStudents, equals('students'));
      expect(ApiEndpoints.tableParents, equals('parents'));
      expect(ApiEndpoints.tableStudentParents, equals('student_parents'));
      expect(ApiEndpoints.tableAdminUsers, equals('admin_users'));
      expect(ApiEndpoints.tableLocations, equals('locations'));
      expect(
        ApiEndpoints.tableStudentPhoneLocations,
        equals('student_phone_locations'),
      );
      expect(ApiEndpoints.tableSchools, equals('schools'));
    });
  });
}
