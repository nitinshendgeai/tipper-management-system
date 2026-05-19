import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/api_error.dart';
import '../models/trip_model.dart';
import '../models/trip_expense_model.dart';
import '../services/trip_service.dart';
import '../services/trip_expense_service.dart';
import '../widgets/trip_status_badge.dart';
import 'add_expense_screen.dart';
import 'complete_trip_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final TripService _tripService = TripService();
  final TripExpenseService _expenseService = TripExpenseService();

  late Future<TripModel> _tripFuture;
  late Future<TripExpenseSummary> _expenseFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _tripFuture = _tripService.getTrip(widget.tripId);
      _expenseFuture = _expenseService.getExpenses(widget.tripId);
    });
  }

  // ─── Start trip dialog ────────────────────────────────────────────────────

  Future<void> _showStartDialog(TripModel trip) async {
    final kmController = TextEditingController(
      text: trip.startKm?.toStringAsFixed(0) ?? '',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Start Trip'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${trip.vehicleNumber}  •  ${trip.sourceLocation} → ${trip.destinationLocation}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Start KM *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('START'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final km = double.tryParse(kmController.text.trim());
    if (km == null || km <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid Start KM'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await _tripService.startTrip(trip.id, km);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load();
        Navigator.pop(context, true); // refresh parent list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiError.extract(e, fallback: 'Failed to start trip. Please try again.')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Add expense ──────────────────────────────────────────────────────────

  Future<void> _openAddExpense(TripModel trip) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(tripId: trip.id)),
    );
    if (result == true) {
      _load();
    }
  }

  // ─── Complete trip ────────────────────────────────────────────────────────

  Future<void> _openComplete(TripModel trip) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CompleteTripScreen(trip: trip)),
    );
    if (result == true) {
      _load();
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ─── Delete expense ───────────────────────────────────────────────────────

  Future<void> _deleteExpense(TripModel trip, TripExpenseModel expense) async {
    try {
      await _expenseService.deleteExpense(trip.id, expense.id);
      if (mounted) {
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiError.extract(e, fallback: 'Failed to delete expense.')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TripModel>(
      future: _tripFuture,
      builder: (ctx, tripSnap) {
        final trip = tripSnap.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(trip == null ? 'Trip Detail' : 'Trip #${trip.id}'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),

          // ── Action buttons (FAB area) ─────────────────────────────────────
          floatingActionButton: trip == null ? null : _buildFAB(trip),

          body: tripSnap.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : tripSnap.hasError
              ? Center(child: Text('Error: ${tripSnap.error}'))
              : _buildBody(trip!),
        );
      },
    );
  }

  Widget? _buildFAB(TripModel trip) {
    if (trip.isStarted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'expense_fab',
            onPressed: () => _openAddExpense(trip),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            tooltip: 'Add Expense',
            child: const Icon(Icons.add_shopping_cart),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'complete_fab',
            onPressed: () => _openComplete(trip),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete Trip'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ],
      );
    }

    if (trip.isCreated) {
      return FloatingActionButton.extended(
        heroTag: 'start_fab',
        onPressed: () => _showStartDialog(trip),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Trip'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      );
    }

    return null;
  }

  Widget _buildBody(TripModel trip) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _buildTripHeader(trip),
          _buildRouteCard(trip),
          _buildOperationalCard(trip),
          if (trip.isStarted || trip.isCompleted) _buildExpenseSection(trip),
          if (trip.isCompleted) _buildCompletionCard(trip),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildTripHeader(TripModel trip) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.teal.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${trip.sourceLocation}  →  ${trip.destinationLocation}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              TripStatusBadge(status: trip.tripStatus),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.fire_truck_outlined,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                trip.vehicleNumber,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                trip.driverName,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
          if (trip.tripDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(trip.tripDate!.toLocal())}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Route info ───────────────────────────────────────────────────────────

  Widget _buildRouteCard(TripModel trip) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              'AI Route Intelligence',
              Icons.auto_awesome,
              Colors.deepPurple,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBox(
                  'Distance',
                  trip.calculatedDistanceKm != null
                      ? '${trip.calculatedDistanceKm!.toStringAsFixed(1)} km'
                      : '—',
                ),
                _statBox(
                  'Duration',
                  trip.estimatedDurationMin != null
                      ? '${trip.estimatedDurationMin} min'
                      : '—',
                ),
                _statBox(
                  'Est. Diesel',
                  trip.estimatedDiesel != null
                      ? '${trip.estimatedDiesel!.toStringAsFixed(1)} L'
                      : '—',
                ),
              ],
            ),
            if (trip.distanceKmOverride != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Distance override: ${trip.distanceKmOverride!.toStringAsFixed(1)} km',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Operational ─────────────────────────────────────────────────────────

  Widget _buildOperationalCard(TripModel trip) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Operational', Icons.settings_outlined, Colors.blueGrey),
            const SizedBox(height: 12),
            if (trip.startKm != null)
              _infoRow(
                Icons.speed_outlined,
                'Start KM',
                '${trip.startKm!.toStringAsFixed(0)} km',
              ),
            if (trip.dieselIssued != null)
              _infoRow(
                Icons.local_gas_station_outlined,
                'Diesel Issued',
                '${trip.dieselIssued!.toStringAsFixed(1)} L',
              ),
            if (trip.tripAdvance != null)
              _infoRow(
                Icons.currency_rupee,
                'Trip Advance',
                '₹${trip.tripAdvance!.toStringAsFixed(0)}',
              ),
            if (trip.startTime != null)
              _infoRow(
                Icons.play_circle_outline,
                'Started At',
                DateFormat('dd MMM, hh:mm a').format(trip.startTime!.toLocal()),
              ),
            if (trip.remarks != null && trip.remarks!.isNotEmpty)
              _infoRow(Icons.notes_outlined, 'Remarks', trip.remarks!),
          ],
        ),
      ),
    );
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Widget _buildExpenseSection(TripModel trip) {
    return FutureBuilder<TripExpenseSummary>(
      future: _expenseFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final summary = snap.data;

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _cardTitle(
                      'Trip Expenses',
                      Icons.receipt_outlined,
                      Colors.orange,
                    ),
                    const Spacer(),
                    if (summary != null)
                      Text(
                        'Total: ₹${summary.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (summary == null || summary.expenses.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No expenses logged yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  // By-type summary chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: summary.byType.entries
                        .map(
                          (e) => Chip(
                            label: Text(
                              '${e.key}: ₹${e.value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.orange.shade50,
                            side: BorderSide(color: Colors.orange.shade200),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  // Individual expense rows
                  ...summary.expenses.map(
                    (expense) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade50,
                        radius: 18,
                        child: Text(
                          expense.expenseType[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      title: Text(
                        expense.expenseType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: expense.remarks != null
                          ? Text(
                              expense.remarks!,
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${expense.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (trip.isStarted) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteExpense(trip, expense),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Completion card ──────────────────────────────────────────────────────

  Widget _buildCompletionCard(TripModel trip) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Trip Summary', Icons.summarize_outlined, Colors.green),
            const SizedBox(height: 12),
            Row(
              children: [
                _statBox(
                  'End KM',
                  trip.endKm != null ? trip.endKm!.toStringAsFixed(0) : '—',
                ),
                _statBox(
                  'Diesel Used',
                  trip.dieselUsed != null
                      ? '${trip.dieselUsed!.toStringAsFixed(1)} L'
                      : '—',
                ),
                _statBox(
                  'Revenue',
                  trip.revenueAmount != null
                      ? '₹${trip.revenueAmount!.toStringAsFixed(0)}'
                      : '—',
                ),
              ],
            ),
            if (trip.endTime != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.check_circle_outline,
                'Completed At',
                DateFormat('dd MMM, hh:mm a').format(trip.endTime!.toLocal()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _cardTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
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
}
