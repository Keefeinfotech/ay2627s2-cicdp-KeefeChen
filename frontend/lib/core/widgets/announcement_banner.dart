import 'package:flutter/material.dart';

/// In-app announcement banner for deployment notices, new features, and downtime.
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({
    super.key,
    required this.message,
    this.type = AnnouncementType.info,
    this.onDismiss,
  });

  final String message;
  final AnnouncementType type;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      AnnouncementType.info => Colors.blue.shade700,
      AnnouncementType.warning => Colors.orange.shade700,
      AnnouncementType.success => Colors.green.shade700,
    };
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

enum AnnouncementType { info, warning, success }
