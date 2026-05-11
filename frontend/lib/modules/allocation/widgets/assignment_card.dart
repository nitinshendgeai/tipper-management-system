import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/assignment_model.dart';

class AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback? onRelease;

  const AssignmentCard({super.key, required this.assignment, this.onRelease});

  Color get _vehicleStatusColor {
    switch (assignment.vehicleStatus) {
      case 'ON_TRIP':
        return Colors.orange;
      case 'ASSIGNED':
        return Colors.blue;
      case 'MAINTENANCE':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Color get _driverStatusColor {
    switch (assignment.driverStatus) {
      case 'ON_TRIP':
        return Colors.orange;
      case 'AVAILABLE':
        return Colors.blue;
      case 'BREAK':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 6),
                Text(
                  'Assignment #${assignment.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: assignment.isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    assignment.isActive ? 'ACTIVE' : 'RELEASED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: assignment.isActive
                          ? Colors.green[800]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Vehicle row ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.fire_truck_outlined,
                  size: 16,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${assignment.vehicleNumber}  •  ${assignment.vehicleType ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                _statusChip(assignment.vehicleStatus, _vehicleStatusColor),
              ],
            ),

            const SizedBox(height: 6),

            // ── Driver row ───────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.teal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${assignment.driverName}  •  ${assignment.driverMobile}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                _statusChip(assignment.driverStatus, _driverStatusColor),
              ],
            ),

            const SizedBox(height: 8),

            // ── Shift date + assigned at ──────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  assignment.shiftDate != null
                      ? DateFormat('dd MMM yyyy').format(assignment.shiftDate!)
                      : '—',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time_outlined,
                  size: 13,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  assignment.assignedAt != null
                      ? fmt.format(assignment.assignedAt!.toLocal())
                      : '—',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            if (assignment.remarks != null &&
                assignment.remarks!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                assignment.remarks!,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],

            // ── Release button (only for active) ─────────────────────────────
            if (assignment.isActive && onRelease != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onRelease,
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('End Shift'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
