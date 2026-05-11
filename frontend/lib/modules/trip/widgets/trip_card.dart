import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import 'trip_status_badge.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onStart,
    this.onComplete,
  });

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: iconColor ?? Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Trip #${trip.id}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TripStatusBadge(status: trip.tripStatus),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),

              const SizedBox(height: 8),

              // ── Route ────────────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${trip.sourceLocation ?? ''}  →  ${trip.destinationLocation ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trip.calculatedDistanceKm != null)
                    Text(
                      '${trip.calculatedDistanceKm!.toStringAsFixed(0)} km',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),

              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),

              _infoRow(
                Icons.fire_truck_outlined,
                'Vehicle',
                trip.vehicleNumber,
                iconColor: Colors.indigo,
              ),
              _infoRow(
                Icons.person_outline,
                'Driver',
                trip.driverName,
                iconColor: Colors.indigo,
              ),

              if (trip.startKm != null)
                _infoRow(
                  Icons.speed_outlined,
                  'Start KM',
                  trip.startKm!.toStringAsFixed(0),
                ),

              if (trip.revenueAmount != null)
                _infoRow(
                  Icons.currency_rupee,
                  'Revenue',
                  '₹${trip.revenueAmount!.toStringAsFixed(0)}',
                  iconColor: Colors.green[700],
                ),

              if (trip.totalLoggedExpense != null &&
                  trip.totalLoggedExpense! > 0)
                _infoRow(
                  Icons.receipt_outlined,
                  'Expenses',
                  '₹${trip.totalLoggedExpense!.toStringAsFixed(0)}',
                  iconColor: Colors.orange,
                ),

              if (trip.isCancelled && trip.cancellationReason != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cancelled: ${trip.cancellationReason}',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
              ],

              // ── Action buttons ───────────────────────────────────────────────
              if (trip.isCreated && onStart != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('START TRIP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],

              if (trip.isStarted && onComplete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('COMPLETE TRIP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
      ),
    );
  }
}
