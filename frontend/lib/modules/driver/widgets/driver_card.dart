import 'package:flutter/material.dart';

import '../models/driver_model.dart';

/// Reusable card displaying driver info with Edit and Delete actions.
/// Follows the same pattern as VehicleCard.
class DriverCard extends StatelessWidget {
  final DriverModel driver;
  final String? assignedVehicleNumber; // resolved from vehicleId externally
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DriverCard({
    super.key,
    required this.driver,
    this.assignedVehicleNumber,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar + name + actions ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.indigo,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          driver.licenseNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
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

            // ── Info grid ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    icon: Icons.phone_outlined,
                    label: 'Mobile',
                    value: driver.mobileNumber,
                  ),
                ),
                Expanded(
                  child: _infoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'License Expiry',
                    value: driver.licenseExpiry,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    icon: Icons.fire_truck_outlined,
                    label: 'Assigned Vehicle',
                    value: assignedVehicleNumber ?? 'Unassigned',
                  ),
                ),
                Expanded(
                  child: _infoTile(
                    icon: Icons.emergency_outlined,
                    label: 'Emergency',
                    value: driver.emergencyContact,
                  ),
                ),
              ],
            ),
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
                value.isNotEmpty ? value : '—',
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
