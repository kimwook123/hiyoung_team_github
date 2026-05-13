import 'package:flutter/material.dart';

import '../models/event_log_item.dart';

// 현재 프레임에 해당하는 이벤트를 영상 위쪽에 간단한 경고 카드로 덧그립니다.
class VideoEventOverlay extends StatelessWidget {
  const VideoEventOverlay({
    super.key,
    required this.items,
  });

  final List<EventLogItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // 너무 많은 카드가 한 번에 보이면 영상이 가려지므로 상위 몇 개만 표시합니다.
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.take(3).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.typeText} / ${item.levelText}\n${item.messageText}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
