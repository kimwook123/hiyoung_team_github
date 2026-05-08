class EventLogItem {
  const EventLogItem({
    required this.timeText,
    required this.frameText,
    required this.eventKeyText,
    required this.statusText,
    required this.typeText,
    required this.personIdText,
    required this.levelText,
    required this.startText,
    required this.startFrameText,
    required this.endText,
    required this.endFrameText,
    required this.durationText,
    required this.clipPathText,
    required this.messageText,
    required this.rawText,
  });

  final String timeText;
  final String frameText;
  final String eventKeyText;
  final String statusText;
  final String typeText;
  final String personIdText;
  final String levelText;
  final String startText;
  final String startFrameText;
  final String endText;
  final String endFrameText;
  final String durationText;
  final String clipPathText;
  final String messageText;
  final String rawText;

  int? get frameValue => _toInt(frameText);
  int? get startFrameValue => _toInt(startFrameText);
  int? get endFrameValue => _toInt(endFrameText);
  bool get hasClip => clipPathText.isNotEmpty && clipPathText != '-';

  bool matchesFrame(int frameValue) {
    final startFrame = startFrameValue;
    final endFrame = endFrameValue;
    if (startFrame == null) {
      return false;
    }

    if (endFrame != null) {
      return frameValue >= startFrame && frameValue <= endFrame;
    }

    return this.frameValue == frameValue || frameValue >= startFrame;
  }

  static int? _toInt(String value) {
    if (value.isEmpty || value == '-') {
      return null;
    }
    return int.tryParse(value);
  }

  factory EventLogItem.fromLine(String line) {
    final values = <String, String>{};
    final parts = line.split(',');

    String timeText = '-';
    if (parts.isNotEmpty) {
      timeText = parts.first.trim();
    }

    for (final part in parts.skip(1)) {
      final index = part.indexOf('=');
      if (index <= 0) {
        continue;
      }

      final key = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();
      values[key] = value;
    }

    return EventLogItem(
      timeText: timeText,
      frameText: values['frame'] ?? '-',
      eventKeyText: values['event_key'] ?? '-',
      statusText: values['status'] ?? '-',
      typeText: values['type'] ?? '-',
      personIdText: values['person_id'] ?? '-',
      levelText: values['level'] ?? '-',
      startText: values['start'] ?? '-',
      startFrameText: values['start_frame'] ?? '-',
      endText: values['end'] ?? '-',
      endFrameText: values['end_frame'] ?? '-',
      durationText: values['duration'] ?? '-',
      clipPathText: values['clip_path'] ?? '-',
      messageText: values['message'] ?? '',
      rawText: line,
    );
  }
}
