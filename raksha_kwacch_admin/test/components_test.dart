import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_button.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_text_field.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_status_badge.dart';
import 'package:raksha_kwacch_admin/shared/widgets/app_dialogs.dart';

void main() {
  group('AppButton Tests', () {
    testWidgets('AppButton displays label and responds to tap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows loading indicator when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppButton(label: 'Loading', isLoading: true)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });
  });

  group('AppTextField Tests', () {
    testWidgets('AppTextField shows label and hint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(label: 'Email', hintText: 'Enter your email'),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('AppTextField validation works', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('AppStatusBadge Tests', () {
    testWidgets('AppStatusBadge displays correct label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStatusBadge(label: 'Active', type: AppStatusType.success),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });
  });

  group('AppConfirmDialog Tests', () {
    testWidgets('AppConfirmDialog displays title and message', (
      WidgetTester tester,
    ) async {
      bool confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton(
                label: 'Open',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AppConfirmDialog(
                      title: 'Confirm Delete',
                      message: 'Are you sure?',
                      onConfirm: () => confirmed = true,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Delete'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });
}
