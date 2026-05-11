import 'package:flutter/material.dart';

class TripStatusBadge extends StatelessWidget {

  final String status;

  const TripStatusBadge({super.key, required this.status});

  Color get _backgroundColor {
    switch (status) {
      case 'Started':
        return Colors.orange.shade100;
      case 'Completed':
        return Colors.green.shade100;
      default: // Created
        return Colors.blue.shade100;
    }
  }

  Color get _textColor {
    switch (status) {
      case 'Started':
        return Colors.orange.shade800;
      case 'Completed':
        return Colors.green.shade800;
      default:
        return Colors.blue.shade800;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'Started':
        return Icons.local_shipping;
      case 'Completed':
        return Icons.check_circle_outline;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: _textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}
