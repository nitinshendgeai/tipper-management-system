import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/token_storage.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

/// Attendance screen — adapts based on user role.
///
/// DRIVER:
///   - Shows Punch In / Punch Out card for today.
///   - Shows own attendance history (last 30 days).
///
/// SUPERVISOR / MANAGER / SUPER_ADMIN:
///   - Shows today's full company attendance list.
///   - Allows punching in / out for any driver.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _service = AttendanceService();

  String? _roleName;
  bool _roleLoaded = false;

  // For DRIVER: own today's record + history
  AttendanceModel? _myTodayRecord;
  List<AttendanceModel> _myHistory = [];
  bool _loadingMyData = true;

  // For SUPERVISOR+: today's company-wide list
  List<AttendanceModel> _todayList = [];
  bool _loadingToday = true;

  // For Punch In dialog (SUPERVISOR+)
  final TextEditingController _driverIdController = TextEditingController();

  bool _isActioning = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final role = await TokenStorage.getRole();
    if (mounted) {
      setState(() {
        _roleName = role;
        _roleLoaded = true;
      });
      _loadData();
    }
  }

  void _loadData() {
    if (_roleName == 'DRIVER') {
      _loadDriverData();
    } else {
      _loadTodayData();
    }
  }

  // ─── DRIVER data ─────────────────────────────────────────────────────────────

  Future<void> _loadDriverData() async {
    setState(() => _loadingMyData = true);
    try {
      final history = await _service.getMyAttendance();
      final today = DateTime.now();
      AttendanceModel? todayRecord;

      for (final r in history) {
        if (r.shiftDate.year == today.year &&
            r.shiftDate.month == today.month &&
            r.shiftDate.day == today.day) {
          todayRecord = r;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _myHistory = history;
          _myTodayRecord = todayRecord;
          _loadingMyData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMyData = false);
    }
  }

  // ─── SUPERVISOR+ data ─────────────────────────────────────────────────────────

  Future<void> _loadTodayData() async {
    setState(() => _loadingToday = true);
    try {
      final list = await _service.getTodayAttendance();
      if (mounted) setState(() { _todayList = list; _loadingToday = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingToday = false);
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _selfPunchIn() async {
    setState(() => _isActioning = true);
    try {
      await _service.punchIn();
      _showSnack('Shift started — you are now ON DUTY ✅', Colors.green);
      _loadDriverData();
    } catch (e) {
      _showSnack(_parseError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _selfPunchOut() async {
    setState(() => _isActioning = true);
    try {
      await _service.punchOut();
      _showSnack('Shift ended — see you tomorrow!', Colors.teal);
      _loadDriverData();
    } catch (e) {
      _showSnack(_parseError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _supervisorPunchIn() async {
    _driverIdController.clear();
    final driverId = await _showDriverIdDialog('Punch In Driver');
    if (driverId == null) return;

    setState(() => _isActioning = true);
    try {
      final record = await _service.punchIn(driverId: driverId);
      _showSnack('${record.driverName} punched in ✅', Colors.green);
      _loadTodayData();
    } catch (e) {
      _showSnack(_parseError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _supervisorPunchOut(AttendanceModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('End Shift?'),
        content: Text('Punch out ${record.driverName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('PUNCH OUT'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActioning = true);
    try {
      await _service.punchOut(driverId: record.driverId);
      _showSnack('${record.driverName} punched out', Colors.teal);
      _loadTodayData();
    } catch (e) {
      _showSnack(_parseError(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('401')) return 'Session expired — please login again.';
    if (msg.contains('403')) return 'Permission denied.';
    if (msg.contains('409')) {
      if (msg.contains('already punched in')) return 'Already punched in today.';
      if (msg.contains('completed a shift')) return 'Shift already completed today.';
      if (msg.contains('ON_TRIP')) return 'Cannot punch out — driver is ON_TRIP.';
    }
    if (msg.contains('404')) return 'Driver not found. Check driver ID.';
    if (msg.contains('SocketException')) return 'Cannot reach server.';
    return 'Action failed. Please try again.';
  }

  Future<int?> _showDriverIdDialog(String title) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title),
          content: TextField(
            controller: _driverIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Driver ID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = int.tryParse(_driverIdController.text.trim());
                Navigator.pop(ctx, id);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDriver = _roleName == 'DRIVER';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: !isDriver
          ? FloatingActionButton.extended(
              onPressed: _isActioning ? null : _supervisorPunchIn,
              icon: const Icon(Icons.login),
              label: const Text('Punch In Driver'),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            )
          : null,
      body: isDriver ? _buildDriverView() : _buildSupervisorView(),
    );
  }

  // ─── DRIVER VIEW ─────────────────────────────────────────────────────────────

  Widget _buildDriverView() {
    if (_loadingMyData) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDriverData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMyTodayCard(),
          const SizedBox(height: 24),
          const Text(
            'Recent History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 12),
          if (_myHistory.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No attendance records yet.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ..._myHistory.map(_buildHistoryTile),
        ],
      ),
    );
  }

  Widget _buildMyTodayCard() {
    final record = _myTodayRecord;
    final fmt = DateFormat('hh:mm a');

    if (record == null) {
      // Not yet punched in today
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.event_available_rounded, size: 48, color: Colors.teal),
              const SizedBox(height: 12),
              const Text(
                'Not yet on duty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isActioning ? null : _selfPunchIn,
                  icon: _isActioning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login),
                  label: const Text('PUNCH IN — START SHIFT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Punched in — show status card
    final isStillOnDuty = record.isOnDuty;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isStillOnDuty ? Colors.teal.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStillOnDuty ? Icons.work_rounded : Icons.check_circle_rounded,
                  color: isStillOnDuty ? Colors.teal : Colors.grey[600],
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  isStillOnDuty ? 'ON DUTY' : 'SHIFT COMPLETE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isStillOnDuty ? Colors.teal : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _infoRow(Icons.login, 'Punch In', record.punchIn != null ? fmt.format(record.punchIn!.toLocal()) : '--'),
            if (record.punchOut != null)
              _infoRow(Icons.logout, 'Punch Out', fmt.format(record.punchOut!.toLocal())),
            _infoRow(Icons.timer_outlined, 'Duration', record.shiftDurationLabel),
            if (isStillOnDuty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isActioning ? null : _selfPunchOut,
                  icon: _isActioning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('PUNCH OUT — END SHIFT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.teal[700]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(AttendanceModel record) {
    final fmt = DateFormat('hh:mm a');
    final dateLabel = DateFormat('dd MMM yyyy').format(record.shiftDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: record.isActive ? Colors.teal.shade100 : Colors.grey.shade200,
          child: Icon(
            record.isActive ? Icons.work_rounded : Icons.check_circle_outline,
            color: record.isActive ? Colors.teal : Colors.grey,
          ),
        ),
        title: Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          record.punchIn != null
              ? '${fmt.format(record.punchIn!.toLocal())} — ${record.punchOut != null ? fmt.format(record.punchOut!.toLocal()) : "On duty"}'
              : 'No punch-in recorded',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          record.shiftDurationLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
      ),
    );
  }

  // ─── SUPERVISOR VIEW ─────────────────────────────────────────────────────────

  Widget _buildSupervisorView() {
    if (_loadingToday) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_todayList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTodayData,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 72, color: Colors.grey[350]),
                  const SizedBox(height: 16),
                  Text(
                    'No drivers on duty today.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Punch In Driver" to mark attendance.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTodayData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _todayList.length,
        itemBuilder: (ctx, i) {
          final record = _todayList[i];
          return _buildSupervisorCard(record);
        },
      ),
    );
  }

  Widget _buildSupervisorCard(AttendanceModel record) {
    final fmt = DateFormat('hh:mm a');
    final isOnDuty = record.isOnDuty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOnDuty ? Colors.teal.shade100 : Colors.grey.shade100,
                  child: Icon(
                    Icons.person,
                    color: isOnDuty ? Colors.teal : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.driverName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnDuty ? Colors.teal : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOnDuty ? 'ON DUTY' : 'DONE',
                    style: TextStyle(
                      color: isOnDuty ? Colors.white : Colors.grey[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                if (record.punchIn != null)
                  _pill(Icons.login, 'In: ${fmt.format(record.punchIn!.toLocal())}'),
                if (record.punchOut != null)
                  _pill(Icons.logout, 'Out: ${fmt.format(record.punchOut!.toLocal())}'),
                _pill(Icons.timer_outlined, record.shiftDurationLabel),
              ],
            ),
            if (isOnDuty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _isActioning ? null : () => _supervisorPunchOut(record),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Punch Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
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

  Widget _pill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
