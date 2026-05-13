class ApiServerHealth {
  const ApiServerHealth({
    required this.status,
    required this.eventLogPath,
    required this.eventLogExists,
  });

  final String status;
  final String eventLogPath;
  final bool eventLogExists;

  factory ApiServerHealth.fromJson(Map<String, dynamic> json) {
    return ApiServerHealth(
      status: _toStringValue(json['status']),
      eventLogPath: _toStringValue(json['event_log_path']),
      eventLogExists: _toBoolValue(json['event_log_exists']),
    );
  }

  static String _toStringValue(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
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
}
