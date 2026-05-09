import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app_theme.dart';
import 'src/demo_route_lifecycle.dart';
import 'src/pages/configure_page.dart';

final ValueNotifier<_FatalAppError?> _fatalAppError = ValueNotifier<_FatalAppError?>(null);

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _reportFatalAppError(details.exception, details.stack ?? StackTrace.current);
      };
      ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
        _reportFatalAppError(error, stackTrace);
        return true;
      };
      runApp(
        _ExampleApp(
          fatalErrorListenable: _fatalAppError,
        ),
      );
    },
    _reportFatalAppError,
  );
}

void _reportFatalAppError(Object error, StackTrace stackTrace) {
  final _FatalAppError fatalError = _FatalAppError(
    title: _isNativeRuntimeLoadFailure(error) ? 'Native runtime load failed' : 'Application fatal error',
    error: error,
    stackTrace: stackTrace,
  );
  _fatalAppError.value = fatalError;
}

bool _isNativeRuntimeLoadFailure(Object error) {
  final String text = error.toString();
  return text.contains('TiRtcNativeLoadException') || text.contains('TiRtcNativeSymbolLookupException');
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp({
    required this.fatalErrorListenable,
  });

  final ValueListenable<_FatalAppError?> fatalErrorListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_FatalAppError?>(
      valueListenable: fatalErrorListenable,
      builder: (BuildContext context, _FatalAppError? fatalError, Widget? child) {
        return MaterialApp(
          title: 'Ti RTC',
          debugShowCheckedModeBanner: false,
          theme: ExampleTheme.build(),
          navigatorObservers: <NavigatorObserver>[exampleRouteObserver],
          home: fatalError == null ? const DemoConfigurePage() : _FatalErrorPage(error: fatalError),
        );
      },
    );
  }
}

final class _FatalAppError {
  const _FatalAppError({
    required this.title,
    required this.error,
    required this.stackTrace,
  });

  final String title;
  final Object error;
  final StackTrace stackTrace;
}

class _FatalErrorPage extends StatelessWidget {
  const _FatalErrorPage({
    required this.error,
  });

  final _FatalAppError error;

  @override
  Widget build(BuildContext context) {
    final TextStyle bodyStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white);
    return Scaffold(
      backgroundColor: const Color(0xFF8F1D2C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                error.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                error.error.toString(),
                style: bodyStyle,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    error.stackTrace.toString(),
                    style: bodyStyle.copyWith(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
