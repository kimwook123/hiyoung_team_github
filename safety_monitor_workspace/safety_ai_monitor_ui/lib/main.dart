import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit 초기화
  MediaKit.ensureInitialized();

  runApp(const SafetyMonitorUiApp());
}
