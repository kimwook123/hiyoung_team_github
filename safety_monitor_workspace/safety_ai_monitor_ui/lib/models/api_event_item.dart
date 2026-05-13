class ApiEventItem {
  const ApiEventItem({
    required this.eventKey,
    required this.eventType,
    required this.status,
    required this.level,
    required this.message,
    required this.frameId,
    required this.personId,
    required this.createdAt,
    required this.durationSeconds,
    required this.clipPath,
    required this.clipUrl,
    required this.serverClipPath,
    required this.serverClipName,
    required this.clipUploadOk,
    required this.sourceTimeText,
    required this.startedSourceTimeText,
    required this.endedSourceTimeText,
    required this.startedFrameId,
    required this.endedFrameId,
    required this.relatedDetections,
  });

  final String eventKey;
  final String eventType;
  final String status;
  final String level;
  final String message;
  final int frameId;
  final int? personId;
  final String createdAt;
  final double durationSeconds;
  final String clipPath;
  final String clipUrl;
  final String serverClipPath;
  final String serverClipName;
  final bool clipUploadOk;
  final String sourceTimeText;
  final String startedSourceTimeText;
  final String endedSourceTimeText;
  final int? startedFrameId;
  final int? endedFrameId;
  final List<Map<String, dynamic>> relatedDetections;

  bool get hasClip => clipPath.isNotEmpty;

  factory ApiEventItem.fromJson(Map<String, dynamic> json) {
    return ApiEventItem(
      eventKey: _toStringValue(json['event_key']),
      eventType: _toStringValue(json['event_type']),
      status: _toStringValue(json['status']),
      level: _toStringValue(json['level']),
      message: _toStringValue(json['message']),
      frameId: _toIntValue(json['frame_id']) ?? 0,
      personId: _toIntValue(json['person_id']),
      createdAt: _toStringValue(json['created_at']),
      durationSeconds: _toDoubleValue(json['duration_seconds']) ?? 0.0,
      clipPath: _toStringValue(json['clip_path']),
      clipUrl: _toStringValue(json['clip_url']),
      serverClipPath: _toStringValue(json['server_clip_path']),
      serverClipName: _toStringValue(json['server_clip_name']),
      clipUploadOk: _toBoolValue(json['clip_upload_ok']),
      sourceTimeText: _toStringValue(json['source_time_text']),
      startedSourceTimeText: _toStringValue(json['started_source_time_text']),
      endedSourceTimeText: _toStringValue(json['ended_source_time_text']),
      startedFrameId: _toIntValue(json['started_frame_id']),
      endedFrameId: _toIntValue(json['ended_frame_id']),
      relatedDetections: _toDetectionList(json['related_detections']),
    );
  }

  static String _toStringValue(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  static int? _toIntValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _toDoubleValue(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static bool _toBoolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  static List<Map<String, dynamic>> _toDetectionList(Object? value) {
    if (value is! List) {
      return const [];
    }

    final items = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        items.add(item);
        continue;
      }

      if (item is Map) {
        items.add(Map<String, dynamic>.from(item));
      }
    }
    return items;
  }
}
