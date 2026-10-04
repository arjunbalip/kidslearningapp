import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// The root widget. Like App.xaml in MAUI: theme + navigation.
class KidsApp extends StatelessWidget {
  const KidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kids Learning App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
