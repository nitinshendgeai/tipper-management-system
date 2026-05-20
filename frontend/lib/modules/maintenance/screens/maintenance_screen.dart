import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/theme/app_theme.dart';
import '../services/maintenance_service.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _service = MaintenanceService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = _service.getMaintenanceLogs());

  Color _statusColor(String? status) {
    switch (status) {
      case 'COMPLETED':   return Colors.green;
      case 'IN_PROGRESS': return Colors.orange;
      case 'SCHEDULED':   return Colors.blue;
      case 'CANCELLED':   return Colors.red;
      default:            return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Maintenance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
            tooltip: 'Log Maintenance',
          ),
        ],
      ),
      drawer: const AppDrawer(activeRoute: 'maintenance'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load: ${snap.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
          }
          final logs = snap.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_circle_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No maintenance logs yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Log Maintenance'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final log = logs[i];
                final status = log['status'] as String? ?? '';
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log['description'] as String? ?? 'Maintenance',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    _statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _InfoChip(
                                icon: Icons.directions_car,
                                label:
                                    'Vehicle #${log['vehicle_id']}'),
                            const SizedBox(width: 8),
                            _InfoChip(
                                icon: Icons.build,
                                label: log['maintenance_type'] as String? ?? ''),
                          ],
                        ),
                        if (log['scheduled_date'] != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            _InfoChip(
                                icon: Icons.calendar_today,
                                label:
                                    'Scheduled: ${log['scheduled_date']}'),
                            if (log['cost'] != null) ...[
                              const SizedBox(width: 8),
                              _InfoChip(
                                  icon: Icons.currency_rupee,
                                  label:
                                      '₹${(log['cost'] as num).toStringAsFixed(0)}'),
                            ],
                          ]),
                        ],
                        if (log['vendor_name'] != null &&
                            (log['vendor_name'] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoChip(
                              icon: Icons.store,
                              label: log['vendor_name'] as String),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final descCtrl      = TextEditingController();
    final vendorCtrl    = TextEditingController();
    final costCtrl      = TextEditingController();
    final vehicleCtrl   = TextEditingController();
    String selectedType = 'ROUTINE';
    String selectedStatus = 'SCHEDULED';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Maintenance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Vehicle ID *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description *'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration:
                    const InputDecoration(labelText: 'Type'),
                items: ['ROUTINE', 'REPAIR', 'TYRE', 'INSPECTION', 'OTHER']
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => selectedType = v ?? selectedType,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration:
                    const InputDecoration(labelText: 'Status'),
                items: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => selectedStatus = v ?? selectedStatus,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costCtrl,
                decoration:
                    const InputDecoration(labelText: 'Cost (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: vendorCtrl,
                decoration:
                    const InputDecoration(labelText: 'Vendor Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (vehicleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
              try {
                await _service.createLog({
                  'vehicle_id': int.parse(vehicleCtrl.text),
                  'description': descCtrl.text.trim(),
                  'maintenance_type': selectedType,
                  'status': selectedStatus,
                  if (costCtrl.text.isNotEmpty)
                    'cost': double.tryParse(costCtrl.text),
                  if (vendorCtrl.text.isNotEmpty)
                    'vendor_name': vendorCtrl.text.trim(),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }
}
