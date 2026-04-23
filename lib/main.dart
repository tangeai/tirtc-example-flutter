import 'package:flutter/material.dart';

import 'src/app_theme.dart';
import 'src/demo_route_lifecycle.dart';
import 'src/pages/configure_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ti RTC',
      debugShowCheckedModeBanner: false,
      theme: ExampleTheme.build(),
      navigatorObservers: <NavigatorObserver>[exampleRouteObserver],
      home: const DemoConfigurePage(),
    );
  }
}
