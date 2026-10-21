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

  Future<AppDatabase> openDatabase(WidgetTester tester) async {
    final database = (await tester.runAsync(AppDatabase.inMemory))!;
    addTearDown(() async {
      await database.close();
    });
    return database;
  }

  void setView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('选择学科后进入专注学习界面，并可完成学习', (tester) async {
    setView(tester);
    final database = await openDatabase(tester);
    final repository = StudyRepository(database);
    final store = StudyStore(repository);
    await tester.runAsync(store.load);

    await tester.pumpWidget(StudyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('选择学科'), findsOneWidget);
    for (final label in ['语文', '数学', '英语', '物理', '化学', '生物']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('开始学习'), findsNothing);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('数学'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('切换学科'), findsOneWidget);
    expect(find.text('管理知识点'), findsOneWidget);
    expect(find.text('开始学习'), findsOneWidget);

    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();
    expect(find.text('今天要学的知识点'), findsOneWidget);
    expect(find.text('集合的概念与表示'), findsOneWidget);

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

    await tester.tap(find.byTooltip('切换学科'));
    await tester.pumpAndSettle();
    expect(find.text('退出学科'), findsOneWidget);
    await tester.tap(find.text('退出学科'));
    await tester.pumpAndSettle();
    expect(find.text('选择学科'), findsOneWidget);

    await tester.tap(find.text('语文'));
    await tester.pumpAndSettle();
    expect(find.text('还没有知识点'), findsOneWidget);
  });

  testWidgets('可以添加知识点并回到学科主页', (tester) async {
    setView(tester);
    final database = await openDatabase(tester);
    final repository = StudyRepository(database);
    final store = StudyStore(repository);
    await tester.runAsync(store.load);

    await tester.pumpWidget(StudyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语文'));
    await tester.pumpAndSettle();
    expect(find.text('还没有知识点'), findsOneWidget);

    await tester.tap(find.text('添加知识点'));
    await tester.pumpAndSettle();
    expect(find.text('知识点 · 语文'), findsOneWidget);

    await tester.tap(find.text('添加第一个知识点'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '第一单元');
    await tester.enterText(fields.at(1), '沁园春·长沙');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    expect(find.text('沁园春·长沙'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('开始学习'), findsOneWidget);
    expect(find.text('已学 0 / 1'), findsOneWidget);
  });

  testWidgets('到期的复习可以完成', (tester) async {
    setView(tester);
    final database = await openDatabase(tester);
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

    await tester.tap(find.text('数学'));
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
