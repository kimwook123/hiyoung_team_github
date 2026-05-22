class SourceItem {
  const SourceItem({
    required this.sourceKey,
    required this.sourceSlug,
    required this.sourceType,
    required this.sourceValue,
    required this.serverMediaPath,
    required this.mediaUrl,
    required this.originalSourceType,
    required this.originalSourceValue,
    required this.clientId,
    required this.sessionId,
    required this.desiredRunning,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sourceKey;
  final String sourceSlug;
  final String sourceType;
  final String sourceValue;
  final String serverMediaPath;
  final String mediaUrl;
  final String originalSourceType;
  final String originalSourceValue;
  final String clientId;
  final String sessionId;
  final bool desiredRunning;
  final String createdAt;
  final String updatedAt;

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      sourceKey: json['source_key']?.toString() ?? '',
      sourceSlug: json['source_slug']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? '',
      sourceValue: json['source_value']?.toString() ?? '',
      serverMediaPath: json['server_media_path']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString() ?? '',
      originalSourceType: json['original_source_type']?.toString() ?? '',
      originalSourceValue: json['original_source_value']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      desiredRunning: json['desired_running'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}
