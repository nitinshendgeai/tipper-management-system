import 'package:flutter/material.dart';

import '../models/route_model.dart';

/// Reusable card displaying route details with Edit and Delete actions.
/// Follows the same pattern as VehicleCard and DriverCard.
class RouteCard extends StatelessWidget {

  final RouteModel route;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RouteCard({
    super.key,
    required this.route,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header: route icon + source→destination + actions ────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.route,
                          color: Colors.teal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.sourceLocation,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 12,
                                  color: Colors.teal[400],
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    route.destinationLocation,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Action buttons ─────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Colors.orange[700],
                          size: 22,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red[600],
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: Colors.grey[200], height: 1),
            const SizedBox(height: 12),

            // ── Info row ─────────────────────────────────────────────────
            Row(
              children: [

                Expanded(
                  child: _infoTile(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: '${route.distanceKm.toStringAsFixed(1)} km',
                  ),
                ),

                if (route.estimatedHours != null)
                  Expanded(
                    child: _infoTile(
                      icon: Icons.access_time_outlined,
                      label: 'Est. Hours',
                      value: '${route.estimatedHours!.toStringAsFixed(1)} hrs',
                    ),
                  ),
              ],
            ),

            // ── Remarks row (only when present) ─────────────────────────
            if (route.remarks != null && route.remarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_outlined, size: 15, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      route.remarks!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
