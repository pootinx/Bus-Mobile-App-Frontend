import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:bus_app/features/notifications/controllers/notification_controller.dart';
import 'package:bus_app/features/notifications/presentation/pages/notifications_page.dart';

class BellIcon extends StatelessWidget {
  final double iconSize;
  final Color iconColor;
  final VoidCallback? onTap;

  const BellIcon({
    super.key,
    this.iconSize = 24,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();

    return Obx(() {
      final count = controller.unreadCount.value;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, size: iconSize, color: iconColor),
            onPressed: onTap ?? () {
              controller.navigateToFullList();
            },
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    });
  }
}
