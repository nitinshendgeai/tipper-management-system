import 'package:flutter/material.dart';

import '../models/assignment_model.dart';
import '../services/allocation_service.dart';
import '../widgets/assignment_card.dart';
import 'create_assignment_screen.dart';

class AllocationScreen extends StatefulWidget {
  const AllocationScreen({super.key});

  @override
  State<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends State<AllocationScreen>
    with SingleTickerProviderStateMixin {
  final AllocationService _service = AllocationService();

  late TabController _tabController;
  late Future<List<AssignmentModel>> _activeFuture;
  late Future<List<AssignmentModel>> _allFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    setState(() {
      _activeFuture = _service.getActiveAssignments();
      _allFuture = _service.getAllAssignments();
    });
  }

  Future<void> _openCreate() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()),
    );
    if (result == true) _loadAll();
  }

  Future<void> _confirmRelease(AssignmentModel assignment) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('End Shift'),
          ],
        ),
        content: Text(
          'Release ${assignment.driverName} from vehicle ${assignment.vehicleNumber}?\n\n'
          'Their shift attendance will be marked complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('END SHIFT'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _release(assignment);
  }

  Future<void> _release(AssignmentModel assignment) async {
    try {
      await _service.releaseAssignment(assignment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${assignment.driverName} released from ${assignment.vehicleNumber}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('ON_TRIP')
                  ? 'Cannot release — vehicle is currently ON_TRIP'
                  : 'Failed to release assignment',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Allocation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Shifts'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Assign Driver'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(
            future: _activeFuture,
            showRelease: true,
            empty: 'No active shifts.\nTap "Assign Driver" to start.',
          ),
          _buildList(
            future: _allFuture,
            showRelease: false,
            empty: 'No assignment history.',
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required Future<List<AssignmentModel>> future,
    required bool showRelease,
    required String empty,
  }) {
    return FutureBuilder<List<AssignmentModel>>(
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                const Text('Failed to load assignments'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 80,
                  color: Colors.grey[350],
                ),
                const SizedBox(height: 16),
                Text(
                  empty,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadAll(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: items.length,
            itemBuilder: (ctx, i) => AssignmentCard(
              assignment: items[i],
              onRelease: showRelease && items[i].isActive
                  ? () => _confirmRelease(items[i])
                  : null,
            ),
          ),
        );
      },
    );
  }
}
