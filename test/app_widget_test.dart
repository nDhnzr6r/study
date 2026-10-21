import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/app.dart';
import 'package:study/data/app_database.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_repository.dart';
import 'package:study/state/study_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('六个学科入口与学习页面可以正常打开', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = (await tester.runAsync(AppDatabase.inMemory))!;
    addTearDown(() async {
      await database.close();
    });
    final store = StudyStore(StudyRepository(database));
    await tester.runAsync(store.load);

    await tester.pumpWidget(StudyApp(store: store));
    await tester.pumpAndSettle();

    for (final label in ['语文', '数学', '英语', '物理', '化学', '生物']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('开始学习'), findsOneWidget);
    expect(find.text('暂无复习'), findsOneWidget);

    await tester.tap(find.text('语文').first);
    await tester.pumpAndSettle();
    expect(find.text('语文计划尚未开放'), findsOneWidget);

    await tester.tap(find.text('数学').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();

    expect(find.text('今天要学的知识点'), findsOneWidget);
    expect(find.text('集合的概念与表示'), findsOneWidget);
    expect(find.text('完成学习'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('完成学习'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('今天学了 1 个知识点'), findsOneWidget);

    await tester.tap(find.text('回到数学'));
    await tester.pumpAndSettle();
    expect(find.text('已学 1 / 41'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('学习数据'), findsOneWidget);
  });

  testWidgets('到期的复习可以完成', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = (await tester.runAsync(AppDatabase.inMemory))!;
    addTearDown(() async {
      await database.close();
    });
    final repository = StudyRepository(database);
    final topics = (await tester.runAsync(
      () => repository.topics(Subject.math),
    ))!;
    await tester.runAsync(
      () => repository.markLearned([
        topics.first.id!,
      ], DateTime.now().subtract(const Duration(days: 1))),
    );

    final store = StudyStore(repository);
    await tester.runAsync(store.load);
    await tester.pumpWidget(StudyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('开始复习'), findsOneWidget);
    await tester.tap(find.text('开始复习'));
    await tester.pumpAndSettle();
    expect(find.text('今天要复习的知识点'), findsOneWidget);
    expect(find.text('第 1 次复习'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('完成复习'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    expect(find.text('完成 1 个知识点的复习'), findsOneWidget);
    await tester.tap(find.text('回到数学'));
    await tester.pumpAndSettle();
    expect(find.text('暂无复习'), findsOneWidget);
  });
}
