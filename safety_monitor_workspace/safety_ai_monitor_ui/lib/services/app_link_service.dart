import 'dart:convert';
import 'dart:io';

import '../models/app_link_info.dart';

// 이 파일은 Flutter와 Python AI Worker 사이의 파일 기반 연결 도구입니다.
// source_state.json, ui_bridge.json, 로그 파일 경로 규칙을 여기서 다룹니다.

class AppLinkService {
  Future<AppLinkInfo?> readDefaultLink() async {
    final bridgeFile = await _findBridgeFile();
    if (bridgeFile == null || !await bridgeFile.exists()) {
      return null;
    }

    final text = await bridgeFile.readAsString();
    final data = jsonDecode(text) as Map<String, dynamic>;
    return AppLinkInfo.fromMap(data);
  }

  Future<File?> _findBridgeFile() async {
    final candidates = await _buildCandidateFiles('ui_bridge.json');

    for (final file in candidates) {
      if (await file.exists()) {
        return file;
      }
    }

    return null;
  }

  Future<void> writeSourceState({
    required String sourceType,
    required String sourceValue,
  }) async {
    // Flutter가 선택한 입력을 source_state.json에 써 주면 Python이 그 값을 읽어 분석을 시작합니다.
    final stateFile = await _getSourceStateFile();
    await stateFile.parent.create(recursive: true);
    final data = {
      'source_type': sourceType,
      'source_value': sourceValue,
    };
    await stateFile.writeAsString(
      jsonEncode(data),
      encoding: utf8,
    );
  }

  Future<void> clearSourceState() async {
    final stateFile = await _getSourceStateFile();
    await stateFile.parent.create(recursive: true);
    await stateFile.writeAsString(
      jsonEncode({
        'source_type': '',
        'source_value': '',
      }),
      encoding: utf8,
    );
  }

  Future<String> buildLogPath({
    required String sourceType,
    required String sourceValue,
  }) async {
    // 파일 로그 모드에서 현재 입력과 대응되는 txt 로그 파일명을 계산합니다.
    final logsDir = await _getLogsDirectory();

    if (sourceType == 'video') {
      final fileName = _getFileName(sourceValue);
      final stem = _getFileStem(fileName);
      return '${logsDir.path}${Platform.pathSeparator}${stem}_event_log.txt';
    }

    if (sourceType == 'stream') {
      return '${logsDir.path}${Platform.pathSeparator}stream_event_log.txt';
    }

    return '${logsDir.path}${Platform.pathSeparator}event_log.txt';
  }

  Future<String> buildJsonEventLogPath() async {
    final logsDir = await _getLogsDirectory();
    return '${logsDir.path}${Platform.pathSeparator}events.jsonl';
  }

  Future<void> clearLogFile({
    required String sourceType,
    required String sourceValue,
  }) async {
    final logPath = await buildLogPath(
      sourceType: sourceType,
      sourceValue: sourceValue,
    );
    final file = File(logPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('', encoding: utf8);
  }

  Future<File> _getSourceStateFile() async {
    final bridgeFile = await _findBridgeFile();
    if (bridgeFile != null) {
      return File(
        '${bridgeFile.parent.path}${Platform.pathSeparator}source_state.json',
      );
    }

    final candidates = await _buildCandidateFiles('source_state.json');
    return candidates.first;
  }

  Future<Directory> _getLogsDirectory() async {
    final bridgeFile = await _findBridgeFile();
    if (bridgeFile != null) {
      return bridgeFile.parent;
    }

    final stateFile = await _getSourceStateFile();
    return stateFile.parent;
  }

  Future<List<File>> _buildCandidateFiles(String fileName) async {
    final currentDir = Directory.current;
    final candidates = <File>[];

    Directory? cursor = currentDir;
    while (cursor != null) {
      candidates.add(
        File(
          '${cursor.path}${Platform.pathSeparator}safety_ai_monitor${Platform.pathSeparator}logs${Platform.pathSeparator}$fileName',
        ),
      );
      candidates.add(
        File(
          '${cursor.path}${Platform.pathSeparator}logs${Platform.pathSeparator}$fileName',
        ),
      );
      cursor = cursor.parent.path == cursor.path ? null : cursor.parent;
    }

    return candidates;
  }

  String _getFileName(String pathText) {
    final normalized = pathText.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? pathText : parts.last;
  }

  String _getFileStem(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }
}
