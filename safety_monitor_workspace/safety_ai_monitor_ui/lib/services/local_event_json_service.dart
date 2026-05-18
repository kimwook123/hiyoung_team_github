import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/api_event_item.dart';

// 파일 로그 모드에서 로컬 events.jsonl을 읽고 변화 여부를 감시합니다.
class LocalEventJsonService {
  Timer? _timer;
  String _lastRawText = '';

  void startWatch({
    required String path,
    required void Function(List<ApiEventItem> items) onChanged,
  }) {
    stopWatch();
    _lastRawText = '';

    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      try {
        final file = File(path);
        if (!await file.exists()) {
          if (_lastRawText.isEmpty) {
            return;
          }

          _lastRawText = '';
          onChanged(const []);
          return;
        }

        final rawText = await file.readAsString();
        if (rawText == _lastRawText) {
          return;
        }

        _lastRawText = rawText;
        onChanged(_parseItems(rawText));
      } on FileSystemException {
        // 다른 프로세스가 파일을 갱신 중이면 다음 주기에 다시 읽는다.
      } catch (_) {
        // 일시적인 읽기/파싱 오류는 다음 주기에 다시 시도한다.
      }
    });
  }

  void stopWatch() {
    _timer?.cancel();
    _timer = null;
    _lastRawText = '';
  }

  Future<List<ApiEventItem>> readItems(String path) async {
    if (path.isEmpty) {
      return const [];
    }

    final file = File(path);
    if (!await file.exists()) {
      return const [];
    }

    final rawText = await file.readAsString();
    _lastRawText = rawText;
    return _parseItems(rawText);
  }

  List<ApiEventItem> _parseItems(String rawText) {
    if (rawText.trim().isEmpty) {
      return const [];
    }

    final items = <ApiEventItem>[];
    final lines = const LineSplitter().convert(rawText);
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(trimmedLine);
        if (decoded is! Map) {
          continue;
        }

        final item = ApiEventItem.fromJson(Map<String, dynamic>.from(decoded));
        items.add(item);
      } catch (_) {
        // 부분 쓰기 중 생긴 깨진 줄은 다음 주기에 다시 읽는다.
      }
    }

    return items;
  }
}
