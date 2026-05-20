class AppLinkInfo {
  const AppLinkInfo({
    required this.sourceKey,
    required this.sourceType,
    required this.sourceValue,
    required this.logPath,
    required this.modelType,
    required this.sourceFps,
  });

  final String sourceKey;
  final String sourceType;
  final String sourceValue;
  final String logPath;
  final String modelType;
  final double sourceFps;

  factory AppLinkInfo.fromMap(Map<String, dynamic> data) {
    final sourceType = (data['source_type'] ?? '') as String;
    final sourceValue = (data['source_value'] ?? '') as String;
    final oldVideoPath = (data['video_path'] ?? '') as String;

    return AppLinkInfo(
      sourceKey: (data['source_key'] ?? '') as String,
      sourceType: sourceType.isEmpty
          ? (oldVideoPath.isEmpty ? '' : 'video')
          : sourceType,
      sourceValue: sourceValue.isEmpty ? oldVideoPath : sourceValue,
      logPath: (data['log_path'] ?? '') as String,
      modelType: (data['model_type'] ?? '') as String,
      sourceFps: ((data['source_fps'] ?? 30) as num).toDouble(),
    );
  }
}
