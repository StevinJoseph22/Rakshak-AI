import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakshak_mobile/screens/locked_screen_alert_screen.dart';
import 'package:rakshak_mobile/services/api_client.dart';
import 'package:rakshak_mobile/services/crash_event_service.dart';

void main() {
  testWidgets('LockedScreenAlertScreen auto-broadcasts incident to backend on timer completion',
      (WidgetTester tester) async {
    bool apiCalled = false;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/incidents') {
        apiCalled = true;
        return http.Response(
          jsonEncode({
            "message": "Incident reported",
            "incident": {
              "id": "alert-test-123",
              "status": "detected",
              "latitude": 12.9716,
              "longitude": 77.5946,
            },
            "matched_hospitals": []
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final testApiClient = ApiClient(
      baseUrl: 'http://10.0.2.2:5000',
      httpClient: mockClient,
    );

    final event = CrashEvent(
      timestamp: DateTime.now(),
      decelerationG: 8.0,
      speedDropKmh: 70.0,
      latitude: 12.9716,
      longitude: 77.5946,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LockedScreenAlertScreen(
          crashEvent: event,
          apiClient: testApiClient,
        ),
      ),
    );

    expect(find.text('CRASH DETECTED'), findsOneWidget);

    // Fast-forward 10 seconds to trigger countdown auto-dispatch
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    expect(apiCalled, isTrue,
        reason: '10s countdown expiry must auto-broadcast incident to backend');
  });

  testWidgets('Cancel button stops countdown and aborts auto-broadcast',
      (WidgetTester tester) async {
    bool apiCalled = false;

    final mockClient = MockClient((request) async {
      apiCalled = true;
      return http.Response('{}', 200);
    });

    final testApiClient = ApiClient(httpClient: mockClient);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LockedScreenAlertScreen(apiClient: testApiClient),
                  ),
                );
              },
              child: const Text('Open Alert'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify on alert screen
    expect(find.text("I'm Okay — Cancel SOS"), findsOneWidget);

    // Tap cancel
    await tester.tap(find.text("I'm Okay — Cancel SOS"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Fast-forward time past 15 seconds to ensure cancelled timer never fires late
    await tester.pump(const Duration(seconds: 15));

    expect(apiCalled, isFalse,
        reason: 'Cancelled alert must never broadcast or fire late');
  });
}
