import 'dart:convert';
import 'dart:io';

class ResolvedInputSource {
  const ResolvedInputSource({
    required this.sourceType,
    required this.sourceValue,
    required this.originalSourceType,
    required this.originalSourceValue,
  });

  final String sourceType;
  final String sourceValue;
  final String originalSourceType;
  final String originalSourceValue;
}

// 입력 소스가 유튜브 링크 같은 간접 주소일 때 실제 열 수 있는 소스로 바꿉니다.
class InputSourceResolverService {
  Future<ResolvedInputSource> resolve({
    required String sourceType,
    required String sourceValue,
  }) async {
    final trimmedSourceType = sourceType.trim();
    final trimmedSourceValue = sourceValue.trim();
    if (trimmedSourceValue.isEmpty) {
      return ResolvedInputSource(
        sourceType: trimmedSourceType,
        sourceValue: trimmedSourceValue,
        originalSourceType: trimmedSourceType,
        originalSourceValue: trimmedSourceValue,
      );
    }

    if (!_isYouTubeUrl(trimmedSourceValue)) {
      return ResolvedInputSource(
        sourceType: trimmedSourceType,
        sourceValue: trimmedSourceValue,
        originalSourceType: trimmedSourceType,
        originalSourceValue: trimmedSourceValue,
      );
    }

    final scriptPath = _findResolverScriptPath();
    if (scriptPath == null) {
      throw Exception('유튜브 입력 변환 스크립트를 찾을 수 없습니다.');
    }

    final pythonCommand = _resolvePythonCommand();
    final result = await Process.run(
      pythonCommand.executable,
      [
        ...pythonCommand.arguments,
        scriptPath,
        trimmedSourceType,
        trimmedSourceValue,
      ],
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr ?? '').toString().trim();
      final stdout = (result.stdout ?? '').toString().trim();
      throw Exception(stderr.isNotEmpty ? stderr : stdout);
    }

    final stdout = (result.stdout ?? '').toString().trim();
    final decoded = jsonDecode(stdout);
    if (decoded is! Map) {
      throw Exception('입력 소스 변환 결과를 해석할 수 없습니다.');
    }

    final ok = decoded['ok'] == true;
    if (!ok) {
      throw Exception(decoded['error']?.toString() ?? '입력 소스 변환에 실패했습니다.');
    }

    return ResolvedInputSource(
      sourceType: decoded['source_type']?.toString() ?? trimmedSourceType,
      sourceValue: decoded['source_value']?.toString() ?? trimmedSourceValue,
      originalSourceType:
          decoded['original_source_type']?.toString() ?? trimmedSourceType,
      originalSourceValue:
          decoded['original_source_value']?.toString() ?? trimmedSourceValue,
    );
  }

  _PythonCommand _resolvePythonCommand() {
    final candidates = <String>[];
    Directory? cursor = Directory.current;
    while (cursor != null) {
      candidates.add(
        '${cursor.path}${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe',
      );
      candidates.add(
        '${cursor.path}${Platform.pathSeparator}..${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe',
      );
      final parent = cursor.parent;
      cursor = parent.path == cursor.path ? null : parent;
    }

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return _PythonCommand(executable: file.path, arguments: const []);
      }
    }

    return const _PythonCommand(executable: 'py', arguments: ['-3']);
  }

  String? _findResolverScriptPath() {
    Directory? cursor = Directory.current;
    while (cursor != null) {
      final candidates = [
        '${cursor.path}${Platform.pathSeparator}safety_ai_monitor'
            '${Platform.pathSeparator}tools${Platform.pathSeparator}resolve_media_source.py',
        '${cursor.path}${Platform.pathSeparator}..${Platform.pathSeparator}safety_ai_monitor'
            '${Platform.pathSeparator}tools${Platform.pathSeparator}resolve_media_source.py',
      ];

      for (final candidate in candidates) {
        final file = File(candidate);
        if (file.existsSync()) {
          return file.path;
        }
      }

      final parent = cursor.parent;
      cursor = parent.path == cursor.path ? null : parent;
    }
    return null;
  }

  bool _isYouTubeUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.contains('youtube.com/') ||
        normalized.contains('youtu.be/') ||
        normalized.contains('youtube-nocookie.com/');
  }
}

class _PythonCommand {
  const _PythonCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}
