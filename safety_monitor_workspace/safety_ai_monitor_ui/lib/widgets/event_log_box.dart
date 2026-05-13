import 'package:flutter/material.dart';

import '../controllers/event_feed_source.dart';
import '../models/event_log_item.dart';

class EventLogBox extends StatelessWidget {
  const EventLogBox({
    super.key,
    required this.eventFeed,
    required this.onTapItem,
  });

  final EventFeedSource eventFeed;
  final void Function(EventLogItem item) onTapItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  '이벤트 로그',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text('총 ${eventFeed.logItems.length}건'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: eventFeed.logItems.isEmpty
                ? const Center(
                    child: Text('표시할 로그가 없습니다.'),
                  )
                : ListView.separated(
                    itemCount: eventFeed.logItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = eventFeed.logItems[index];
                      return _LogTile(
                        item: item,
                        isSelected:
                            eventFeed.selectedKeys.contains(item.eventKeyText),
                        onTap: () => onTapItem(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final EventLogItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isSelected,
      onTap: onTap,
      title: Text('${item.typeText} / ${item.levelText}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.messageText),
          const SizedBox(height: 4),
          Text(
            'time=${item.timeText} person=${item.personIdText} duration=${item.durationText}',
          ),
          Text('start=${item.startText} end=${item.endText}'),
          if (item.hasClip) Text('clip=${item.clipPathText}'),
        ],
      ),
    );
  }
}
