import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inbox_app/ui/workbench_sidebar.dart';

void main() {
  Widget harness(double width) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: 400,
          child: WorkbenchSidebar(
            sidebar: const Text('SIDE'),
            child: Builder(
              builder: (context) => IconButton(
                key: const Key('sidebar-toggle'),
                onPressed: WorkbenchSidebarScope.of(context).toggle,
                icon: const Icon(Icons.menu),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('wide shell docks sidebar and narrow shell folds it', (tester) async {
    await tester.pumpWidget(harness(800));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsOneWidget);

    await tester.pumpWidget(harness(500));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsOneWidget);

    await tester.pumpWidget(harness(800));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsOneWidget);
  });

  testWidgets('initially narrow shell folds, then docks after crossing', (tester) async {
    await tester.pumpWidget(harness(500));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsNothing);

    await tester.pumpWidget(harness(800));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsOneWidget);
  });

  testWidgets('manual wide toggle persists until width crosses threshold', (tester) async {
    await tester.pumpWidget(harness(800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsNothing);

    await tester.pumpWidget(harness(800));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsNothing);

    await tester.pumpWidget(harness(500));
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness(800));
    await tester.pumpAndSettle();
    expect(find.text('SIDE'), findsOneWidget);
  });
}
