import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/ui/widgets/common.dart';

void main() {
  testWidgets('进度条长度变化带动画', (tester) async {
    final value = ValueNotifier<double>(0);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: ValueListenableBuilder<double>(
                valueListenable: value,
                builder: (context, current, child) {
                  return ProgressBar(value: current, height: 8);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    value.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    var fraction = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fraction.widthFactor, greaterThan(0));
    expect(fraction.widthFactor, lessThan(1));

    await tester.pumpAndSettle();
    fraction = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fraction.widthFactor, 1);
  });
}
