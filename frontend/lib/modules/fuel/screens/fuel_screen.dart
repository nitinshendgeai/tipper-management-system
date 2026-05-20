import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/theme/app_theme.dart';
import '../services/fuel_service.dart';

class FuelScreen extends StatefulWidget {
  const FuelScreen({super.key});

  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  final _service = FuelService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = _service.getFuelLogs());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Fuel Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'Log Fuel',
          ),
        ],
      ),
      drawer: const AppDrawer(activeRoute: 'fuel'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Failed to load: ${snap.error}'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ]),
            );
          }
          final logs = snap.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_gas_station_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No fuel logs yet',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Log Fuel'),
                ),
              ]),
            );
          }

          // Summary bar
          double totalLitres = 0;
          double totalCost = 0;
          for (final log in logs) {
            totalLitres += (log['litres'] as num? ?? 0).toDouble();
            totalCost += (log['cost'] as num? ?? 0).toDouble();
          }

          return Column(
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    _SummaryTile(
                        label: 'Total Litres',
                        value: '${totalLitres.toStringAsFixed(1)} L'),
                    const SizedBox(width: 16),
                    _SummaryTile(
                        label: 'Total Cost',
                        value:
                            '₹${totalCost.toStringAsFixed(0)}'),
                    const SizedBox(width: 16),
                    _SummaryTile(
                        label: 'Entries',
                        value: '${logs.length}'),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.orange
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.local_gas_station,
                                    color: Colors.orange,
                                    size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vehicle #${log['vehicle_id']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${log['litres'] ?? '-'} L  •  ₹${log['cost'] ?? '-'}  •  ${log['fuel_date'] ?? ''}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                    if (log['station_name'] != null &&
                                        (log['station_name'] as String)
                                            .isNotEmpty)
                                      Text(
                                        log['station_name'] as String,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                              ),
                              if (log['odometer_km'] != null)
                                Text(
                                  '${log['odometer_km']} km',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500]),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final vehicleCtrl  = TextEditingController();
    final litresCtrl   = TextEditingController();
    final costCtrl     = TextEditingController();
    final stationCtrl  = TextEditingController();
    final odomCtrl     = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Fuel'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: vehicleCtrl,
              decoration:
                  const InputDecoration(labelText: 'Vehicle ID *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: litresCtrl,
              decoration:
                  const InputDecoration(labelText: 'Litres *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: costCtrl,
              decoration:
                  const InputDecoration(labelText: 'Cost (₹) *'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: stationCtrl,
              decoration:
                  const InputDecoration(labelText: 'Station Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: odomCtrl,
              decoration:
                  const InputDecoration(labelText: 'Odometer (km)'),
              keyboardType: TextInputType.number,
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (vehicleCtrl.text.isEmpty ||
                  litresCtrl.text.isEmpty ||
                  costCtrl.text.isEmpty) return;
              try {
                await _service.createLog({
                  'vehicle_id': int.parse(vehicleCtrl.text),
                  'litres': double.parse(litresCtrl.text),
                  'cost': double.parse(costCtrl.text),
                  'fuel_date':
                      DateTime.now().toIso8601String().substring(0, 10),
                  if (stationCtrl.text.isNotEmpty)
                    'station_name': stationCtrl.text.trim(),
                  if (odomCtrl.text.isNotEmpty)
                    'odometer_km': double.tryParse(odomCtrl.text),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
