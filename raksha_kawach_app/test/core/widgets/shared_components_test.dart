import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raksha_kawach_app/core/theme/app_colors.dart';
import 'package:raksha_kawach_app/core/theme/app_theme.dart';
import 'package:raksha_kawach_app/core/widgets/pill_badge.dart';
import 'package:raksha_kawach_app/core/widgets/raksha_brand_emblem.dart';
import 'package:raksha_kawach_app/features/student/models/attendance_record.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/metric_tile.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/presence_bar_chart.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/transit_route_geometry.dart';
import 'package:raksha_kawach_app/features/student/views/widgets/verification_status_badge.dart';

void main() {
  Widget wrapWithTheme(Widget child, {TextScaler? textScaler}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            textScaler: textScaler ?? TextScaler.noScaling,
            size: const Size(390, 844),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  group('RakshaBrandEmblem Component Tests', () {
    testWidgets('Renders base emblem with official logo asset and semantics', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const RakshaBrandEmblem(size: 48, useAssetLogo: true)),
      );

      expect(find.byType(RakshaBrandEmblem), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      final semantics = tester.getSemantics(find.byType(RakshaBrandEmblem));
      expect(semantics.label, contains('Raksha Kawach Live System Shield'));
    });

    testWidgets('Renders fallback shield icon when useAssetLogo is false', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const RakshaBrandEmblem(size: 48, useAssetLogo: false)),
      );

      expect(find.byType(RakshaBrandEmblem), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('Renders live pulsing dot when showLivePing is true', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const RakshaBrandEmblem(size: 48, showLivePing: true)),
      );

      // Verify pulse stack rendered
      expect(find.byType(Stack), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RakshaBrandEmblem), findsOneWidget);
    });

    testWidgets('Adapts to custom size and color configurations in fallback mode', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const RakshaBrandEmblem(
            size: 64,
            useAssetLogo: false,
            backgroundColor: AppColors.primary,
            iconColor: Colors.white,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.shield_outlined));
      expect(icon.color, Colors.white);
      expect(icon.size, 64 * 0.52);
    });
  });

  group('PillBadge Component Tests', () {
    testWidgets('Renders text and default neutral styling', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const PillBadge(text: 'Campus Transit')),
      );

      expect(find.text('Campus Transit'), findsOneWidget);
    });

    testWidgets('Renders all PillBadgeVariant styles without error', (tester) async {
      for (final variant in PillBadgeVariant.values) {
        await tester.pumpWidget(
          wrapWithTheme(PillBadge(text: variant.name, variant: variant)),
        );
        expect(find.text(variant.name), findsOneWidget);
      }
    });

    testWidgets('Renders with icon and monospace formatting for vehicle plate', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const PillBadge(
            text: 'KA-04-E-2104',
            variant: PillBadgeVariant.inverse,
            isMonospace: true,
            icon: Icons.directions_bus,
          ),
        ),
      );

      expect(find.text('KA-04-E-2104'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bus), findsOneWidget);
    });

    testWidgets('Handles tight constraint without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 80,
              child: PillBadge(text: 'Very Long Status Text Overflowing'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('TransitRouteGeometry Component Tests', () {
    testWidgets('Renders origin, transport identifier, and destination', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const TransitRouteGeometry(
            origin: 'North Quad',
            transportIdentifier: 'Bus 08',
            destination: 'Main Gate',
            isIllustrative: true,
          ),
        ),
      );

      expect(find.text('North Quad'), findsOneWidget);
      expect(find.text('Bus 08'), findsOneWidget);
      expect(find.text('Main Gate'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bus), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.textContaining('Route geometry visualization'), findsOneWidget);
    });

    testWidgets('Hides illustrative disclaimer when isIllustrative is false', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const TransitRouteGeometry(
            origin: 'Hostel Stop',
            transportIdentifier: 'Route 04',
            destination: 'Faculty Block',
            isIllustrative: false,
          ),
        ),
      );

      expect(find.text('Hostel Stop'), findsOneWidget);
      expect(find.textContaining('Route geometry visualization'), findsNothing);
    });

    testWidgets('Renders cleanly on narrow screen width (320px)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: TransitRouteGeometry(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('PresenceBarChart Component Tests', () {
    testWidgets('Renders genuine empty state when records list is empty', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const PresenceBarChart(records: [])),
      );

      expect(find.text('Weekly Presence'), findsOneWidget);
      expect(find.text('No Data'), findsOneWidget);
      expect(find.textContaining('No attendance records found'), findsOneWidget);
    });

    testWidgets('Calculates genuine verified percentage from records (not hardcoded 96%)', (tester) async {
      // Create 2 records: 1 verified, 1 unverified -> 50%
      final mondayRecord = AttendanceRecord(
        id: 'rec-001',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime(2026, 11, 9, 8, 15), // Monday
        verificationStatus: 'phone_present',
      );

      final tuesdayRecord = AttendanceRecord(
        id: 'rec-002',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime(2026, 11, 10, 8, 20), // Tuesday
        verificationStatus: 'phone_not_nearby',
      );

      await tester.pumpWidget(
        wrapWithTheme(PresenceBarChart(records: [mondayRecord, tuesdayRecord])),
      );

      // Verify computed 50% (1/2 verified)
      expect(find.text('50% Verified (1/2)'), findsOneWidget);
      // Confirm hardcoded 96% is NOT present
      expect(find.textContaining('96%'), findsNothing);

      // Weekday letters M through F rendered
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2)); // Tuesday and Thursday
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('Computes 100% verified when all weekday records are phone_present', (tester) async {
      final record = AttendanceRecord(
        id: 'rec-100',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime(2026, 11, 11, 8, 30), // Wednesday
        verificationStatus: 'phone_present',
      );

      await tester.pumpWidget(
        wrapWithTheme(PresenceBarChart(records: [record])),
      );

      expect(find.text('100% Verified (1/1)'), findsOneWidget);
    });

    testWidgets('Renders full 7-day presence chart including Saturday and Sunday scans', (tester) async {
      final saturdayRecord = AttendanceRecord(
        id: 'rec-sat',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime.utc(2026, 11, 14, 12, 2), // 17:32 IST Saturday
        verificationStatus: 'phone_present',
      );
      final sundayRecord = AttendanceRecord(
        id: 'rec-sun',
        studentId: 'stu-001',
        attendanceStatus: 'present',
        scannedAt: DateTime.utc(2026, 11, 14, 21, 14), // 02:44 IST Sunday
        verificationStatus: 'phone_present',
      );

      await tester.pumpWidget(
        wrapWithTheme(PresenceBarChart(records: [saturdayRecord, sundayRecord])),
      );

      expect(find.text('100% Verified (2/2)'), findsOneWidget);
      // Both Saturday and Sunday 'S' labels rendered
      expect(find.text('S'), findsNWidgets(2));
      // Real scan times displayed in IST
      expect(find.text('17:32'), findsOneWidget);
      expect(find.text('02:44'), findsOneWidget);
    });
  });

  group('MetricTile Component Tests', () {
    testWidgets('Renders label, value, and optional unit', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MetricTile(
            label: 'GPS Precision',
            value: '±4.2',
            unit: 'm',
            icon: Icons.gps_fixed,
          ),
        ),
      );

      expect(find.text('GPS Precision'), findsOneWidget);
      expect(find.text('±4.2'), findsOneWidget);
      expect(find.text('m'), findsOneWidget);
      expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    });

    testWidgets('Supports container background mode', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MetricTile(
            label: 'Proximity Radius',
            value: '14.8',
            unit: 'm',
            showBackground: true,
          ),
        ),
      );

      expect(find.text('Proximity Radius'), findsOneWidget);
      expect(find.text('14.8'), findsOneWidget);
    });
  });

  group('VerificationStatusBadge Component Tests', () {
    testWidgets('Maps phone_present correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const VerificationStatusBadge(status: 'phone_present')),
      );

      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('Maps phone_not_nearby correctly without disciplinary strike implication', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const VerificationStatusBadge(status: 'phone_not_nearby')),
      );

      expect(find.text('Phone Not Nearby'), findsOneWidget);
      expect(find.byIcon(Icons.cell_tower), findsOneWidget);
      // Confirm no strike label
      expect(find.textContaining('Strike'), findsNothing);
    });

    testWidgets('Maps location_unavailable correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const VerificationStatusBadge(status: 'location_unavailable')),
      );

      expect(find.text('Location Unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.location_disabled_outlined), findsOneWidget);
    });

    testWidgets('Maps verification_uncertain correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const VerificationStatusBadge(status: 'verification_uncertain')),
      );

      expect(find.text('Verification Uncertain'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem_outlined), findsOneWidget);
    });

    testWidgets('Maps null status to Pending Verification', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const VerificationStatusBadge(status: null)),
      );

      expect(find.text('Pending Verification'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('Renders trailing distance metric when distanceMeters is provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const VerificationStatusBadge(
            status: 'phone_present',
            distanceMeters: 12.4,
          ),
        ),
      );

      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.text('12.4m GPS Distance'), findsOneWidget);
      expect(find.byIcon(Icons.satellite_alt_outlined), findsOneWidget);
    });
  });

  group('Accessibility & Text Scaling Tests', () {
    testWidgets('Shared components scale gracefully with 1.5x accessibility text scaling', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RakshaBrandEmblem(size: 48),
              SizedBox(height: 12),
              PillBadge(text: 'KA-04-E-2104', isMonospace: true),
              SizedBox(height: 12),
              MetricTile(label: 'GPS Accuracy', value: '±3.5', unit: 'm'),
              SizedBox(height: 12),
              VerificationStatusBadge(status: 'phone_present', distanceMeters: 14.8),
            ],
          ),
          textScaler: const TextScaler.linear(1.5),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('KA-04-E-2104'), findsOneWidget);
      expect(find.text('Phone Verified'), findsOneWidget);
    });
  });
}

