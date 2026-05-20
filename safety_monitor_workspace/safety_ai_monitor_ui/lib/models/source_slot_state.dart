class SourceSlotState {
  const SourceSlotState({
    required this.slotId,
    required this.sourceType,
    required this.sourceValue,
    this.clientId = '',
    this.sessionId = '',
  });

  final String slotId;
  final String sourceType;
  final String sourceValue;
  final String clientId;
  final String sessionId;

  Map<String, dynamic> toJson() {
    return {
      'slot_id': slotId,
      'source_type': sourceType,
      'source_value': sourceValue,
      'client_id': clientId,
      'session_id': sessionId,
    };
  }
}
