import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state/study_store.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme.dart';

class StudyApp extends StatelessWidget {
  const StudyApp({super.key, required this.store});

  final StudyStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: Consumer<StudyStore>(
        builder: (context, state, child) {
          return MaterialApp(
            title: 'Study',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
