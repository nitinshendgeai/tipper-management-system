import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/theme/app_theme.dart';
import '../services/document_service.dart';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  final _service = DocumentService();
  late Future<List<Map<String, dynamic>>> _future;
  String _filterCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = _service.getDocuments());

  Color _expiryColor(String? expiryDate) {
    if (expiryDate == null) return Colors.grey;
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return Colors.grey;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0)  return Colors.red;
    if (daysLeft <= 7) return Colors.red;
    if (daysLeft <= 30) return Colors.orange;
    return Colors.green;
  }

  String _expiryLabel(String? expiryDate) {
    if (expiryDate == null) return 'No expiry';
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return expiryDate;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0)  return 'Expired ${-daysLeft}d ago';
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft <= 30) return 'Expires in ${daysLeft}d';
    return expiryDate.substring(0, 10);
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'DRIVER':    return Icons.badge;
      case 'VEHICLE':   return Icons.directions_car;
      case 'INSURANCE': return Icons.shield;
      case 'PERMIT':    return Icons.article;
      default:          return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'Add Document',
          ),
        ],
      ),
      drawer: const AppDrawer(activeRoute: 'documents'),
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

          final all = snap.data ?? [];
          final docs = _filterCategory == 'ALL'
              ? all
              : all
                  .where((d) => d['category'] == _filterCategory)
                  .toList();

          // Count expiring soon
          final expiringSoon = all.where((d) {
            final e = d['expiry_date'] as String?;
            if (e == null) return false;
            final expiry = DateTime.tryParse(e);
            if (expiry == null) return false;
            return expiry.difference(DateTime.now()).inDays <= 30;
          }).length;

          return Column(
            children: [
              // Alert banner
              if (expiringSoon > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: Colors.orange.withValues(alpha: 0.1),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$expiringSoon document(s) expiring within 30 days',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),

              // Category filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: ['ALL', 'DRIVER', 'VEHICLE', 'INSURANCE', 'PERMIT', 'OTHER']
                      .map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: _filterCategory == cat,
                              onSelected: (_) =>
                                  setState(() => _filterCategory = cat),
                              selectedColor: AppColors.primary
                                  .withValues(alpha: 0.15),
                            ),
                          ))
                      .toList(),
                ),
              ),

              if (docs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No documents found',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _showAddDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Document'),
                          ),
                        ]),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _load(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final expColor =
                            _expiryColor(doc['expiry_date'] as String?);
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
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _categoryIcon(
                                        doc['category'] as String?),
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['document_name'] as String? ??
                                            'Document',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${doc['category'] ?? ''}'
                                        '${doc['document_number'] != null ? ' • ${doc['document_number']}' : ''}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Icon(Icons.circle,
                                          size: 8, color: expColor),
                                      const SizedBox(height: 4),
                                      Text(
                                        _expiryLabel(
                                            doc['expiry_date']
                                                as String?),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: expColor,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ]),
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
    final nameCtrl   = TextEditingController();
    final numberCtrl = TextEditingController();
    final notesCtrl  = TextEditingController();
    final expiryCtrl = TextEditingController();
    String selectedCategory = 'VEHICLE';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Document'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['DRIVER', 'VEHICLE', 'INSURANCE', 'PERMIT', 'OTHER']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => selectedCategory = v ?? selectedCategory,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Document Name *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: numberCtrl,
              decoration:
                  const InputDecoration(labelText: 'Document Number'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: expiryCtrl,
              decoration: const InputDecoration(
                  labelText: 'Expiry Date (YYYY-MM-DD)'),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
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
              if (nameCtrl.text.isEmpty) return;
              try {
                await _service.createDocument({
                  'category': selectedCategory,
                  'document_name': nameCtrl.text.trim(),
                  if (numberCtrl.text.isNotEmpty)
                    'document_number': numberCtrl.text.trim(),
                  if (expiryCtrl.text.isNotEmpty)
                    'expiry_date': expiryCtrl.text.trim(),
                  if (notesCtrl.text.isNotEmpty)
                    'notes': notesCtrl.text.trim(),
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
