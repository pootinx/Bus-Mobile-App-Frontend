import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/notifications/controllers/notification_controller.dart';
import 'package:bus_app/features/notifications/models/notification_model.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = NotificationController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Obx(() {
            if (ctrl.unreadCount.value == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: () => ctrl.markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ctrl.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        final grouped = _groupByDate(ctrl.notifications);
        return ListView.builder(
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final entry = grouped.entries.elementAt(index);
            return _DateGroup(
              dateLabel: entry.key,
              notifications: entry.value,
              isDark: isDark,
            );
          },
        );
      }),
    );
  }

  Map<String, List<AppNotification>> _groupByDate(List<AppNotification> items) {
    final map = <String, List<AppNotification>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final date = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else {
        label = '${date.day}/${date.month}/${date.year}';
      }
      map.putIfAbsent(label, () => []);
      map[label]!.add(item);
    }
    return map;
  }
}

class _DateGroup extends StatelessWidget {
  final String dateLabel;
  final List<AppNotification> notifications;
  final bool isDark;

  const _DateGroup({
    required this.dateLabel,
    required this.notifications,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            dateLabel,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        ...notifications.map((n) => _NotificationListTile(
          notification: n,
          isDark: isDark,
        )),
      ],
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;

  const _NotificationListTile({
    required this.notification,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = NotificationController.to;
    final isSurvey = notification.type == NotificationType.survey;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: notification.isRead
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFF3B82F6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.mark_email_read, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        ctrl.markAsRead(notification.id);
        return false;
      },
      child: Material(
        color: notification.isRead
            ? (isDark ? Colors.transparent : Colors.white)
            : (isDark ? const Color(0xFF1A2A3A) : const Color(0xFFF0F7FF)),
        child: InkWell(
          onTap: () => ctrl.navigateToNotification(notification),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isSurvey
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.15),
                  child: Icon(
                    isSurvey ? Icons.assignment : Icons.notifications,
                    color: isSurvey ? Colors.orange : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title ?? '',
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body ?? '',
                        style: TextStyle(
                          color: notification.isRead
                              ? (isDark ? Colors.grey[400] : Colors.grey[600])
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(notification.createdAt),
                        style: TextStyle(
                          color: notification.isRead ? Colors.grey[500] : const Color(0xFF3B82F6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
