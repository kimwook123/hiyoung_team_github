import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'models/clip_window_arguments.dart';
import 'screens/clip_player_window.dart';
import 'services/embedded_backend_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit 초기화
  MediaKit.ensureInitialized();

  final commandLineArguments = _tryResolveClipWindowArguments(args);
  if (commandLineArguments != null) {
    runApp(
      SafetyMonitorClientApp(
        title: commandLineArguments.title,
        home: ClipPlayerWindow(arguments: commandLineArguments),
      ),
    );
    return;
  }

  final windowController = await WindowController.fromCurrentEngine();
  final clipWindowArguments = ClipWindowArguments.tryParse(
    windowController.arguments,
  );
  if (clipWindowArguments != null) {
    runApp(
      SafetyMonitorClientApp(
        title: clipWindowArguments.title,
        home: ClipPlayerWindow(arguments: clipWindowArguments),
      ),
    );
    return;
  }

  runApp(const SafetyMonitorClientApp());
  unawaited(EmbeddedBackendService.instance.ensureStarted());
}

ClipWindowArguments? _tryResolveClipWindowArguments(List<String> args) {
  for (final raw in args) {
    final parsed = ClipWindowArguments.tryParse(raw);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
