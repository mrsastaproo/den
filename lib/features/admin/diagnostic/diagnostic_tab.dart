import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/auth_service.dart';
import '../core/admin_core_widgets.dart';

class DiagnosticTab extends ConsumerStatefulWidget {
  const DiagnosticTab({super.key});

  @override
  ConsumerState<DiagnosticTab> createState() => _DiagnosticTabState();
}

class _DiagnosticTabState extends ConsumerState<DiagnosticTab> {
  final _handleCtrl = TextEditingController();
  Map<String, dynamic>? _lookupResult;
  bool _loading = false;
  String? _error;

  Future<void> _doLookup() async {
    if (_handleCtrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _lookupResult = null;
    });
    try {
      final res = await ref.read(adminServiceProvider).lookupHandle(_handleCtrl.text);
      setState(() => _lookupResult = res);
      if (res == null) setState(() => _error = "Handle NOT found in database.");
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _doRescue() async {
    final myUid = ref.read(authServiceProvider).currentUser?.uid;
    if (myUid == null || _lookupResult == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(adminServiceProvider).rescueHandle(_handleCtrl.text, myUid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SUCCESS: Handle and Friends rescued to your account!')),
      );
      _doLookup(); // Refresh
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Handle Rescue Diagnostic',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you lost your data, type your previous handle (e.g. robit) below to find the "Ghost" account and re-link its data to your current login.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AdminSearchBar(
                  ctrl: _handleCtrl,
                  hint: 'Enter handle (e.g. robit)',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _loading ? null : _doLookup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Lookup', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: AdminLoader()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: AdminErrorCard(message: _error!),
            ),
          if (_lookupResult != null) ...[
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OWNER FOUND:', style: TextStyle(color: Color(0xFFFF3366), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _InfoField('Current UID', _lookupResult!['uid']),
                  _InfoField('Linked Email', _lookupResult!['email']),
                  _InfoField('Linkage status', _lookupResult!['hasProfile'] ? "Profile doc exists" : "Orphaned (No profile doc)"),
                  const Divider(height: 40, color: Colors.white10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _doRescue,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('RESCUE TO MY ACCOUNT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11D47B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This will move the handle ownership AND your friends list to your current profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label, value;
  const _InfoField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
