import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/admin_service.dart';
import '../core/admin_core_widgets.dart';

class ConfigTab extends ConsumerWidget {
  const ConfigTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminConfigProvider);
    return async.when(
      loading: () => const AdminLoader(),
      error: (e, _) => AdminErrorCard(message: e.toString()),
      data: (config) => _ConfigBody(config: config),
    );
  }
}

class _ConfigBody extends ConsumerStatefulWidget {
  final AppConfig config;
  const _ConfigBody({required this.config});

  @override
  ConsumerState<_ConfigBody> createState() => _ConfigBodyState();
}

class _ConfigBodyState extends ConsumerState<_ConfigBody> {
  late bool _maintenance;
  late bool _forceUpdate;
  late bool _audius;
  late bool _jiosaavn;
  late bool _registration;
  late String _maintenanceMsg;
  late String _welcomeMsg;
  late String _minVersion;
  late String _latestVersion;
  late String _updateMsg;
  late int _maxSearch;
  late int _maxHistory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reset(widget.config);
  }

  @override
  void didUpdateWidget(_ConfigBody old) {
    super.didUpdateWidget(old);
    if (old.config != widget.config && !_saving) {
      _reset(widget.config);
    }
  }

  void _reset(AppConfig c) {
    _maintenance = c.maintenanceMode;
    _forceUpdate = c.forceUpdate;
    _audius = c.audiusEnabled;
    _jiosaavn = c.jiosaavnEnabled;
    _registration = c.registrationEnabled;
    _maintenanceMsg = c.maintenanceMessage;
    _welcomeMsg = c.welcomeMessage;
    _minVersion = c.minVersion;
    _latestVersion = c.latestVersion;
    _updateMsg = c.updateMessage;
    _maxSearch = c.maxSearchResults;
    _maxHistory = c.maxHistoryItems;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        const AdminSectionHeader(title: 'App Status', icon: Icons.power_settings_new_rounded),
        const SizedBox(height: 8),
        AdminGlassCard(children: [
          _ConfigSwitch(
            label: 'Maintenance Mode',
            subtitle: 'Block all users from accessing the app',
            icon: Icons.construction_rounded,
            color: const Color(0xFFFF4444),
            value: _maintenance,
            onChanged: (v) => setState(() => _maintenance = v),
          ),
          if (_maintenance)
            _ConfigTextField(
              label: 'Maintenance Message',
              value: _maintenanceMsg,
              onChanged: (v) => setState(() => _maintenanceMsg = v),
            ),
          _ConfigSwitch(
            label: 'New Registrations',
            subtitle: 'Allow new users to sign up',
            icon: Icons.person_add_rounded,
            color: const Color(0xFF11D47B),
            value: _registration,
            onChanged: (v) => setState(() => _registration = v),
          ),
        ]),

        const SizedBox(height: 16),
        const AdminSectionHeader(title: 'Version Control', icon: Icons.new_releases_rounded),
        const SizedBox(height: 8),
        AdminGlassCard(children: [
          _ConfigTextField(label: 'Min Supported Version', value: _minVersion, onChanged: (v) => setState(() => _minVersion = v)),
          _ConfigTextField(label: 'Latest Version', value: _latestVersion, onChanged: (v) => setState(() => _latestVersion = v)),
        ]),

        const SizedBox(height: 16),
        const AdminSectionHeader(title: 'Music Sources', icon: Icons.api_rounded),
        const SizedBox(height: 8),
        AdminGlassCard(children: [
          _ConfigSwitch(
            label: 'JioSaavn API', subtitle: 'Main Hindi / Bollywood music source',
            icon: Icons.music_note_rounded, color: const Color(0xFFFF3366),
            value: _jiosaavn, onChanged: (v) => setState(() => _jiosaavn = v),
          ),
          _ConfigSwitch(
            label: 'Audius API', subtitle: 'English / independent music source',
            icon: Icons.headphones_rounded, color: const Color(0xFF6C63FF),
            value: _audius, onChanged: (v) => setState(() => _audius = v),
          ),
        ]),
        
        const SizedBox(height: 16),
        const AdminSectionHeader(title: 'Messages', icon: Icons.message_rounded),
        const SizedBox(height: 8),
        AdminGlassCard(children: [
          _ConfigTextField(label: 'Welcome Message', value: _welcomeMsg, onChanged: (v) => setState(() => _welcomeMsg = v)),
        ]),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF3366), Color(0xFF6C63FF)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Configuration', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(adminServiceProvider).updateAppConfig({
        'maintenanceMode': _maintenance,
        'maintenanceMessage': _maintenanceMsg,
        'forceUpdate': _forceUpdate,
        'updateMessage': _updateMsg,
        'audiusEnabled': _audius,
        'jiosaavnEnabled': _jiosaavn,
        'registrationEnabled': _registration,
        'maxSearchResults': _maxSearch,
        'maxHistoryItems': _maxHistory,
        'welcomeMessage': _welcomeMsg,
        'minVersion': _minVersion,
        'latestVersion': _latestVersion,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved!')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ConfigSwitch extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConfigSwitch({required this.label, required this.subtitle, required this.icon, required this.color, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: const Color(0xFF11D47B)),
      ]),
    );
  }
}

class _ConfigTextField extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  const _ConfigTextField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
