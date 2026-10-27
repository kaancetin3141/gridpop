import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'state/app_scope.dart';
import 'screens/home/home_screen.dart';

/// Root widget of GridPop.
///
/// Only two things can change the app shell: the theme and the language, both
/// owned by [SettingsController]. Every other state change rebuilds a much
/// smaller subtree.
class GridPopApp extends StatefulWidget {
  const GridPopApp({super.key, required this.services});

  final AppServices services;

  @override
  State<GridPopApp> createState() => _GridPopAppState();
}

class _GridPopAppState extends State<GridPopApp> {
  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: ListenableBuilder(
        listenable: widget.services.settings,
        builder: (BuildContext context, Widget? child) {
          final settings = widget.services.settings;
          return MaterialApp(
            title: 'GridPop',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            locale: settings.locale,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}