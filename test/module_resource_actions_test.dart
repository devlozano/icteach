import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/module_model.dart';
import 'package:icteach/widgets/module_resource_actions.dart';

ModuleModel module(String link) => ModuleModel(
  id: 'lesson',
  classId: 'class',
  title: 'Lesson',
  description: '',
  content: '',
  attachmentUrl: link,
  fileName: 'Lesson.pdf',
  order: 1,
  isPublished: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('invalid Open link gives actionable error and enables retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleResourceActions(
            classId: 'class',
            module: module('invalid'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open resource'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ask your teacher to attach'), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opened resource is not reported failed when tracking is unavailable',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModuleResourceActions(
              classId: 'class',
              module: module('https://example.org/lesson.pdf'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open resource'));
      await tester.pumpAndSettle();
      expect(calls.any((call) => call.method == 'launch'), isTrue);
      expect(
        find.text(
          'Resource opened, but activity tracking could not be updated.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Resource action failed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
