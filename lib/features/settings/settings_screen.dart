import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_theme.dart';
import 'edit_profile_screen.dart';
import '../../core/services/settings_service.dart';
import 'equalizer_screen.dart';
import '../../core/providers/music_providers.dart';

// ─── EXTRA SETTINGS PROVIDERS ────────────────────────────────

final crossfadeEnabledProvider = StateProvider<bool>((ref) => false);
final crossfadeDurationProvider = StateProvider<double>((ref) => 3.0);
final normalizationEnabledProvider = StateProvider<bool>((ref) => true);
final autoplayEnabledProvider = StateProvider<bool>((ref) => true);
final explicitContentProvider = StateProvider<bool>((ref) => true);
final dataWarningProvider = StateProvider<bool>((ref) => true);
final offlineModeProvider = StateProvider<bool>((ref) => false);
final gaplessPlaybackProvider = StateProvider<bool>((ref) => true);
final showNotificationsProvider = StateProvider<bool>((ref) => true);
final sleepTimerProvider = StateProvider<String?>((ref) => null);
final carModeProvider = StateProvider<bool>((ref) => false);
final showLyricsProvider = StateProvider<bool>((ref) => true);
final privateSessionProvider = StateProvider<bool>((ref) => false);

// ─── SETTINGS SCREEN ─────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
        slivers: [

          // ── Header ──────────────────────────────────────────
          SliverToBoxAdapter(child: _Header()),

          // ── Profile Card ────────────────────────────────────
          SliverToBoxAdapter(child: _ProfileCard(user: user)),

          // ── Stats ───────────────────────────────────────────
          SliverToBoxAdapter(child: _StatsRow()),

          // ── 1. Music Playback ───────────────────────────────
          SliverToBoxAdapter(child: _PlaybackSection()),

          // ── 2. Audio Quality ────────────────────────────────
          SliverToBoxAdapter(child: _AudioQualitySection()),

          // ── 3. Downloads ────────────────────────────────────
          SliverToBoxAdapter(child: _DownloadsSection()),

          // ── 4. Language & Content ───────────────────────────
          SliverToBoxAdapter(child: _ContentSection()),

          // ── 5. Appearance ───────────────────────────────────
          SliverToBoxAdapter(child: _AppearanceSection()),

          // ── 6. Social & Privacy ─────────────────────────────
          SliverToBoxAdapter(child: _PrivacySection()),

          // ── 7. Notifications ────────────────────────────────
          SliverToBoxAdapter(child: _NotificationsSection()),

          // ── 8. Storage & Data ───────────────────────────────
          SliverToBoxAdapter(child: _StorageSection()),

          // ── 9. About ────────────────────────────────────────
          SliverToBoxAdapter(child: _AboutSection()),

          // ── Sign Out ────────────────────────────────────────
          SliverToBoxAdapter(child: _SignOutButton()),

          // ── Delete Account ──────────────────────────────────
          SliverToBoxAdapter(child: _DeleteAccountButton()),

          const SliverToBoxAdapter(child: SizedBox(height: 180)),
        ],
      ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20, right: 20, bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.settings_rounded,
                    color: Colors.white, size: 24)),
              const SizedBox(width: 10),
              const Text('Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PROFILE CARD ─────────────────────────────────────────────

class _ProfileCard extends ConsumerWidget {
  final dynamic user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.15),
                  AppTheme.purple.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.pink.withOpacity(0.4),
                        blurRadius: 20, spreadRadius: -5),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.transparent,
                    child: user?.photoURL != null
                        ? ClipOval(child: CachedNetworkImage(
                            imageUrl: user.photoURL,
                            width: 72, height: 72,
                            fit: BoxFit.cover))
                        : Text(
                            (user?.email?.substring(0, 1)
                                .toUpperCase()) ?? 'D',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ??
                            user?.email?.split('@')[0] ??
                            'DEN User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(user?.email ?? 'Not signed in',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12)),
                      const SizedBox(height: 8),
                      // Free badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.music_note_rounded,
                                color: Colors.white, size: 11),
                            SizedBox(width: 4),
                            Text('Free Plan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()));
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15))),
                        child: ShaderMask(
                          shaderCallback: (b) =>
                              AppTheme.primaryGradient.createShader(b),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 18)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms)
        .slideY(begin: -0.05, end: 0, duration: 500.ms);
  }
}

// ─── STATS ROW ────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedSongsProvider).value?.length ?? 0;
    final history = ref.watch(historyProvider).value?.length ?? 0;
    final playlists = ref.watch(playlistsProvider).value?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: _StatChip(
            value: '$liked', label: 'Liked',
            icon: Icons.favorite_rounded,
            colors: [AppTheme.pink, AppTheme.pinkDeep])),
          const SizedBox(width: 10),
          Expanded(child: _StatChip(
            value: '$history', label: 'Played',
            icon: Icons.history_rounded,
            colors: [AppTheme.purple, AppTheme.purpleDeep])),
          const SizedBox(width: 10),
          Expanded(child: _StatChip(
            value: '$playlists', label: 'Playlists',
            icon: Icons.queue_music_rounded,
            colors: [AppTheme.pinkDeep, AppTheme.purple])),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 80.ms);
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final List<Color> colors;
  const _StatChip({required this.value, required this.label,
      required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              colors[0].withOpacity(0.15),
              colors[1].withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors[0].withOpacity(0.2)),
          ),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    LinearGradient(colors: colors).createShader(b),
                child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(height: 6),
              Text(value,
                style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 1. PLAYBACK SECTION ──────────────────────────────────────

class _PlaybackSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossfade = ref.watch(crossfadeEnabledProvider);
    final crossfadeDur = ref.watch(crossfadeDurationProvider);
    final normalize = ref.watch(normalizationEnabledProvider);
    final autoplay = ref.watch(autoplayEnabledProvider);
    final gapless = ref.watch(gaplessPlaybackProvider);
    final lyrics = ref.watch(showLyricsProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final carMode = ref.watch(carModeProvider);

    return _Section(
      title: 'Playback',
      icon: Icons.play_circle_rounded,
      delay: 1,
      children: [
        _SwitchTile(
          icon: Icons.shuffle_on_rounded,
          label: 'Crossfade',
          subtitle: 'Smooth transitions between songs',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          value: crossfade,
          onChanged: (v) {
            ref.read(crossfadeEnabledProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        if (crossfade) ...[
          _SliderTile(
            icon: Icons.linear_scale_rounded,
            label: 'Crossfade Duration',
            subtitle: '${crossfadeDur.toInt()}s',
            colors: [AppTheme.pink, AppTheme.purple],
            value: crossfadeDur,
            min: 1, max: 12,
            onChanged: (v) =>
                ref.read(crossfadeDurationProvider.notifier).state = v,
          ),
        ],
        _SwitchTile(
          icon: Icons.volume_up_rounded,
          label: 'Volume Normalization',
          subtitle: 'Keep volume consistent across songs',
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          value: normalize,
          onChanged: (v) {
            ref.read(normalizationEnabledProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _SwitchTile(
          icon: Icons.skip_next_rounded,
          label: 'Autoplay',
          subtitle: 'Continue with similar songs when queue ends',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          value: autoplay,
          onChanged: (v) {
            ref.read(autoplayEnabledProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _SwitchTile(
          icon: Icons.queue_music_rounded,
          label: 'Gapless Playback',
          subtitle: 'No silence between tracks',
          colors: [AppTheme.pink, AppTheme.purple],
          value: gapless,
          onChanged: (v) {
            ref.read(gaplessPlaybackProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _SwitchTile(
          icon: Icons.lyrics_rounded,
          label: 'Show Lyrics',
          subtitle: 'Display lyrics in player when available',
          colors: [AppTheme.purple, AppTheme.pinkDeep],
          value: lyrics,
          onChanged: (v) {
            ref.read(showLyricsProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _NavTile(
          icon: Icons.equalizer_rounded,
          label: 'Equalizer',
          subtitle: 'Fine-tune your sound',
          value: 'Normal',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const EqualizerScreen())),
        ),
        _NavTile(
          icon: Icons.bedtime_rounded,
          label: 'Sleep Timer',
          subtitle: 'Stop playing after a set time',
          value: sleepTimer ?? 'Off',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () => _showSleepTimerSheet(context, ref, sleepTimer),
        ),
        _SwitchTile(
          icon: Icons.directions_car_rounded,
          label: 'Car Mode',
          subtitle: 'Simplified interface for driving',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          value: carMode,
          onChanged: (v) {
            ref.read(carModeProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }

  void _showSleepTimerSheet(BuildContext context,
      WidgetRef ref, String? current) {
    final options = ['Off', '5 min', '10 min', '15 min',
        '30 min', '45 min', '1 hour', 'End of track'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GlassSheet(
        title: 'Sleep Timer',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (_, i) {
            final opt = options[i];
            final isSelected =
                (current == null && opt == 'Off') || current == opt;
            return _SheetOption(
              label: opt,
              icon: opt == 'Off'
                  ? Icons.timer_off_rounded
                  : Icons.bedtime_rounded,
              isSelected: isSelected,
              onTap: () {
                ref.read(sleepTimerProvider.notifier).state =
                    opt == 'Off' ? null : opt;
                Navigator.pop(context);
                HapticFeedback.selectionClick();
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── 2. AUDIO QUALITY SECTION ─────────────────────────────────

class _AudioQualitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamQ = ref.watch(streamingQualityProvider);

    return _Section(
      title: 'Audio Quality',
      icon: Icons.high_quality_rounded,
      delay: 2,
      children: [
        _NavTile(
          icon: Icons.stream_rounded,
          label: 'Streaming Quality',
          subtitle: 'Quality when playing over network',
          value: streamQ,
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showQualitySheet(
            context, ref, 'Streaming', streamQ,
            (q) => ref.read(streamingQualityProvider.notifier).set(q)),
        ),
        _NavTile(
          icon: Icons.wifi_rounded,
          label: 'WiFi Quality',
          subtitle: 'Use higher quality on WiFi',
          value: 'Auto',
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.signal_cellular_alt_rounded,
          label: 'Mobile Data Quality',
          subtitle: 'Reduce quality to save data',
          value: '160kbps',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => _showQualitySheet(
            context, ref, 'Mobile Data', '160kbps',
            (q) {}),
        ),
        _NavTile(
          icon: Icons.headphones_rounded,
          label: 'Audio Format',
          subtitle: 'MP3, AAC, or FLAC when available',
          value: 'MP3',
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () {},
        ),
      ],
    );
  }

  void _showQualitySheet(BuildContext context, WidgetRef ref,
      String type, String current, Function(String) onSelect) {
    final qualities = [
      {'value': '96kbps', 'label': 'Low', 'desc': 'Saves the most data'},
      {'value': '160kbps', 'label': 'Normal', 'desc': 'Good balance'},
      {'value': '320kbps', 'label': 'High', 'desc': 'Best quality'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: '$type Quality',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: qualities.length,
          itemBuilder: (_, i) {
            final q = qualities[i];
            final isSel = q['value'] == current;
            return _SheetOption(
              label: q['value']!,
              subtitle: '${q['label']} • ${q['desc']}',
              icon: Icons.high_quality_rounded,
              isSelected: isSel,
              onTap: () {
                onSelect(q['value']!);
                Navigator.pop(context);
                HapticFeedback.selectionClick();
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── 3. DOWNLOADS SECTION ─────────────────────────────────────

class _DownloadsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlQ = ref.watch(downloadQualityProvider);
    final offline = ref.watch(offlineModeProvider);
    final dataWarn = ref.watch(dataWarningProvider);

    return _Section(
      title: 'Downloads',
      icon: Icons.download_rounded,
      delay: 3,
      children: [
        _NavTile(
          icon: Icons.download_for_offline_rounded,
          label: 'Download Quality',
          subtitle: 'Quality of offline saved songs',
          value: dlQ,
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          onTap: () => _showDlQualitySheet(context, ref, dlQ),
        ),
        _SwitchTile(
          icon: Icons.offline_bolt_rounded,
          label: 'Offline Mode',
          subtitle: 'Only play downloaded songs',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          value: offline,
          onChanged: (v) {
            ref.read(offlineModeProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _SwitchTile(
          icon: Icons.data_saver_on_rounded,
          label: 'Data Saver Warning',
          subtitle: 'Alert before streaming on mobile data',
          colors: [AppTheme.pink, AppTheme.purple],
          value: dataWarn,
          onChanged: (v) {
            ref.read(dataWarningProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _NavTile(
          icon: Icons.folder_rounded,
          label: 'Storage Location',
          subtitle: 'Where downloads are saved',
          value: 'Internal',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () => _showComingSoon(context, 'Storage Location'),
        ),
        _NavTile(
          icon: Icons.delete_sweep_rounded,
          label: 'Clear Downloads',
          subtitle: 'Free up space by removing offline songs',
          value: '',
          colors: [AppTheme.pinkDeep, AppTheme.pink],
          onTap: () => _showClearDownloadsDialog(context),
          isDestructive: true,
        ),
      ],
    );
  }

  void _showDlQualitySheet(BuildContext context,
      WidgetRef ref, String current) {
    final qualities = [
      {'value': '96kbps', 'label': 'Low', 'desc': 'Uses less storage'},
      {'value': '160kbps', 'label': 'Normal', 'desc': 'Balanced'},
      {'value': '320kbps', 'label': 'High', 'desc': 'Best quality'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Download Quality',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: qualities.length,
          itemBuilder: (_, i) {
            final q = qualities[i];
            final isSel = q['value'] == current;
            return _SheetOption(
              label: q['value']!,
              subtitle: '${q['label']} • ${q['desc']}',
              icon: Icons.download_rounded,
              isSelected: isSel,
              onTap: () {
                ref.read(downloadQualityProvider.notifier).set(q['value']!);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  void _showClearDownloadsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Clear Downloads',
        message: 'This will remove all downloaded songs from your device.',
        confirmLabel: 'Clear',
        isDestructive: true,
        onConfirm: () => Navigator.pop(context),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature — coming soon!',
          style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.black.withOpacity(0.85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 1500),
    ));
  }
}

// ─── 4. CONTENT & LANGUAGE SECTION ───────────────────────────

class _ContentSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(musicLanguageProvider);
    final explicit = ref.watch(explicitContentProvider);

    return _Section(
      title: 'Language & Content',
      icon: Icons.language_rounded,
      delay: 4,
      children: [
        _NavTile(
          icon: Icons.language_rounded,
          label: 'Music Language',
          subtitle: 'Filter songs by language',
          value: language,
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () => _showLanguageSheet(context, ref, language),
        ),
        _SwitchTile(
          icon: Icons.explicit_rounded,
          label: 'Allow Explicit Content',
          subtitle: 'Show songs with explicit lyrics',
          colors: [AppTheme.pinkDeep, AppTheme.purpleDeep],
          value: explicit,
          onChanged: (v) {
            ref.read(explicitContentProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        _NavTile(
          icon: Icons.tune_rounded,
          label: 'Content Preferences',
          subtitle: 'Genres and artists you prefer',
          value: '',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () => _showComingSoon(context),
        ),
        _NavTile(
          icon: Icons.block_rounded,
          label: 'Blocked Artists',
          subtitle: 'Manage artists you don\'t want to hear',
          value: '0 blocked',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showComingSoon(context),
        ),
      ],
    );
  }

  void _showLanguageSheet(BuildContext context,
      WidgetRef ref, String current) {
    final langs = [
      {'value': 'Hindi + English', 'emoji': '🌍'},
      {'value': 'Hindi', 'emoji': '🇮🇳'},
      {'value': 'English', 'emoji': '🇬🇧'},
      {'value': 'Punjabi', 'emoji': '🎵'},
      {'value': 'Tamil', 'emoji': '🎶'},
      {'value': 'Telugu', 'emoji': '🎸'},
      {'value': 'Marathi', 'emoji': '🎺'},
      {'value': 'Bengali', 'emoji': '🎻'},
      {'value': 'All Languages', 'emoji': '🌏'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GlassSheet(
        title: 'Music Language',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: langs.length,
          itemBuilder: (_, i) {
            final l = langs[i];
            final isSel = l['value'] == current;
            return _SheetOption(
              label: l['value']!,
              emoji: l['emoji'],
              isSelected: isSel,
              onTap: () {
                ref.read(musicLanguageProvider.notifier)
                    .set(l['value']!);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Coming soon!',
          style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.black.withOpacity(0.85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 1200),
    ));
  }
}

// ─── 5. APPEARANCE SECTION ────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Appearance',
      icon: Icons.palette_rounded,
      delay: 5,
      children: [
        _NavTile(
          icon: Icons.dark_mode_rounded,
          label: 'Theme',
          subtitle: 'App color scheme',
          value: 'Dark',
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          onTap: () => _showThemeSheet(context),
        ),
        _NavTile(
          icon: Icons.color_lens_rounded,
          label: 'Accent Color',
          subtitle: 'Primary highlight color',
          value: 'Pink + Purple',
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () => _showColorSheet(context),
        ),
        _NavTile(
          icon: Icons.text_fields_rounded,
          label: 'Font Size',
          subtitle: 'Adjust text size across the app',
          value: 'Medium',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => _showFontSizeSheet(context),
        ),
        _NavTile(
          icon: Icons.animation_rounded,
          label: 'Animations',
          subtitle: 'Reduce motion for accessibility',
          value: 'Full',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.album_rounded,
          label: 'Album Art Style',
          subtitle: 'Vinyl disc or square card',
          value: 'Vinyl',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showArtStyleSheet(context),
        ),
      ],
    );
  }

  void _showThemeSheet(BuildContext context) {
    final themes = ['Dark', 'Pure Black (AMOLED)', 'Auto (System)'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Theme',
        child: Column(children: themes.map((t) => _SheetOption(
          label: t,
          icon: Icons.dark_mode_rounded,
          isSelected: t == 'Dark',
          onTap: () => Navigator.pop(context),
        )).toList()),
      ),
    );
  }

  void _showColorSheet(BuildContext context) {
    final themes = [
      {'name': 'Pink + Purple', 'c1': AppTheme.pink, 'c2': AppTheme.purple},
      {'name': 'Red + Orange',
        'c1': const Color(0xFFFF6B6B), 'c2': const Color(0xFFFFB347)},
      {'name': 'Blue + Cyan',
        'c1': const Color(0xFF6BB8FF), 'c2': const Color(0xFF47FFD4)},
      {'name': 'Green + Teal',
        'c1': const Color(0xFF6BFF8C), 'c2': const Color(0xFF47FFD4)},
      {'name': 'Gold + Amber',
        'c1': const Color(0xFFFFD700), 'c2': const Color(0xFFFFB347)},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Accent Color',
        child: Column(
          children: themes.map((t) {
            final c1 = t['c1'] as Color;
            final c2 = t['c2'] as Color;
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08))),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [c1, c2]),
                        shape: BoxShape.circle)),
                    const SizedBox(width: 14),
                    Text(t['name'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (t['name'] == 'Pink + Purple')
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFontSizeSheet(BuildContext context) {
    final sizes = ['Small', 'Medium', 'Large', 'Extra Large'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Font Size',
        child: Column(children: sizes.map((s) => _SheetOption(
          label: s,
          icon: Icons.text_fields_rounded,
          isSelected: s == 'Medium',
          onTap: () => Navigator.pop(context),
        )).toList()),
      ),
    );
  }

  void _showArtStyleSheet(BuildContext context) {
    final styles = ['Vinyl Disc', 'Square Card', 'Circle'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Album Art Style',
        child: Column(children: styles.map((s) => _SheetOption(
          label: s,
          icon: Icons.album_rounded,
          isSelected: s == 'Vinyl Disc',
          onTap: () => Navigator.pop(context),
        )).toList()),
      ),
    );
  }
}

// ─── 6. SOCIAL & PRIVACY SECTION ─────────────────────────────

class _PrivacySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privateSession = ref.watch(privateSessionProvider);

    return _Section(
      title: 'Social & Privacy',
      icon: Icons.shield_rounded,
      delay: 6,
      children: [
        _SwitchTile(
          icon: Icons.visibility_off_rounded,
          label: 'Private Session',
          subtitle: 'Don\'t save listening history temporarily',
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          value: privateSession,
          onChanged: (v) {
            ref.read(privateSessionProvider.notifier).state = v;
            HapticFeedback.selectionClick();
            if (v) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Private session started',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.black.withOpacity(0.85),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            }
          },
        ),
        _NavTile(
          icon: Icons.history_rounded,
          label: 'Listening History',
          subtitle: 'Manage your play history',
          value: '',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showClearHistoryDialog(context, ref),
        ),
        _NavTile(
          icon: Icons.manage_accounts_rounded,
          label: 'Privacy Settings',
          subtitle: 'Control what data DEN collects',
          value: '',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => _showPrivacySheet(context),
        ),
        _NavTile(
          icon: Icons.privacy_tip_rounded,
          label: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          value: '',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () => _showPrivacyPolicy(context),
        ),
        _NavTile(
          icon: Icons.description_rounded,
          label: 'Terms of Service',
          subtitle: 'Read terms and conditions',
          value: '',
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () => _showTermsSheet(context),
        ),
      ],
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Clear Listening History',
        message: 'This will remove all songs from your recent history. This cannot be undone.',
        confirmLabel: 'Clear History',
        isDestructive: true,
        onConfirm: () async {
          await ref.read(databaseServiceProvider).clearHistory();
          if (context.mounted) Navigator.pop(context);
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Privacy Settings',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Data Collection', 'Minimal — only what\'s needed'),
              const SizedBox(height: 12),
              _InfoRow('Analytics', 'Anonymous usage stats only'),
              const SizedBox(height: 12),
              _InfoRow('Third Parties', 'JioSaavn API, Audius, Firebase'),
              const SizedBox(height: 12),
              _InfoRow('Data Storage', 'Encrypted on Firebase'),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GlassSheet(
        title: 'Privacy Policy',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'DEN collects minimal data to provide a personalized music experience. '
            'We use Firebase for authentication and data storage. '
            'Your listening history is stored to improve recommendations. '
            'We do not sell your data to third parties. '
            '\n\nYou can delete your account and all associated data at any time from Settings.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Terms of Service',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'By using DEN, you agree to use the app for personal, '
            'non-commercial use only. Music content is streamed via licensed APIs. '
            'Do not record, redistribute, or use content for commercial purposes.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 7. NOTIFICATIONS SECTION ────────────────────────────────

class _NotificationsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(showNotificationsProvider);

    return _Section(
      title: 'Notifications',
      icon: Icons.notifications_rounded,
      delay: 7,
      children: [
        _SwitchTile(
          icon: Icons.notifications_active_rounded,
          label: 'Push Notifications',
          subtitle: 'New releases and app updates',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          value: notifs,
          onChanged: (v) {
            ref.read(showNotificationsProvider.notifier).state = v;
            HapticFeedback.selectionClick();
          },
        ),
        if (notifs) ...[
          _SwitchTile(
            icon: Icons.new_releases_rounded,
            label: 'New Releases',
            subtitle: 'When artists you follow drop new music',
            colors: [AppTheme.purple, AppTheme.purpleDeep],
            value: true,
            onChanged: (_) => HapticFeedback.selectionClick(),
          ),
          _SwitchTile(
            icon: Icons.recommend_rounded,
            label: 'Recommendations',
            subtitle: 'Personalized music suggestions',
            colors: [AppTheme.pinkDeep, AppTheme.purple],
            value: false,
            onChanged: (_) => HapticFeedback.selectionClick(),
          ),
          _SwitchTile(
            icon: Icons.update_rounded,
            label: 'App Updates',
            subtitle: 'New features and improvements',
            colors: [AppTheme.pink, AppTheme.purple],
            value: true,
            onChanged: (_) => HapticFeedback.selectionClick(),
          ),
        ],
      ],
    );
  }
}

// ─── 8. STORAGE & DATA SECTION ───────────────────────────────

class _StorageSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Storage & Data',
      icon: Icons.storage_rounded,
      delay: 8,
      children: [
        _InfoTile(
          icon: Icons.storage_rounded,
          label: 'Cache Size',
          value: '12.4 MB',
          colors: [AppTheme.purple, AppTheme.purpleDeep],
        ),
        _NavTile(
          icon: Icons.cleaning_services_rounded,
          label: 'Clear Cache',
          subtitle: 'Free up space from temporary files',
          value: '',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showClearCacheDialog(context),
          isDestructive: false,
        ),
        _InfoTile(
          icon: Icons.download_done_rounded,
          label: 'Downloaded Songs',
          value: '0 songs',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
        ),
        _NavTile(
          icon: Icons.wifi_off_rounded,
          label: 'Offline Storage Used',
          subtitle: 'Space used by downloaded songs',
          value: '0 MB',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () {},
        ),
      ],
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Clear Cache',
        message: 'This will clear 12.4 MB of cached images and data. '
            'App performance may temporarily be slower.',
        confirmLabel: 'Clear Cache',
        isDestructive: false,
        onConfirm: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Cache cleared',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.black.withOpacity(0.85),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 1500),
          ));
        },
      ),
    );
  }
}

// ─── 9. ABOUT SECTION ────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'About',
      icon: Icons.info_rounded,
      delay: 9,
      children: [
        _NavTile(
          icon: Icons.info_rounded,
          label: 'About DEN',
          subtitle: 'Version, credits, open source',
          value: 'v1.0.0',
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () => _showAboutSheet(context),
        ),
        _NavTile(
          icon: Icons.star_rounded,
          label: 'Rate DEN',
          subtitle: 'Enjoying the app? Leave a review!',
          value: '⭐⭐⭐⭐⭐',
          colors: [AppTheme.purple, AppTheme.pinkDeep],
          onTap: () => _showComingSoon(context),
        ),
        _NavTile(
          icon: Icons.share_rounded,
          label: 'Share DEN',
          subtitle: 'Tell your friends about DEN',
          value: '',
          colors: [AppTheme.pinkDeep, AppTheme.pink],
          onTap: () => _showComingSoon(context),
        ),
        _NavTile(
          icon: Icons.bug_report_rounded,
          label: 'Report a Bug',
          subtitle: 'Help us improve DEN',
          value: '',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showComingSoon(context),
        ),
        _NavTile(
          icon: Icons.help_rounded,
          label: 'Help & Support',
          subtitle: 'FAQs and contact support',
          value: '',
          colors: [AppTheme.purple, AppTheme.pink],
          onTap: () => _showComingSoon(context),
        ),
      ],
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'About DEN',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Text('DEN',
                  style: TextStyle(
                    color: Colors.white, fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3))),
              const SizedBox(height: 6),
              Text('Version 1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13)),
              const SizedBox(height: 12),
              Text('Your music, your world.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              _InfoRow('Built with', 'Flutter 3.x'),
              const SizedBox(height: 8),
              _InfoRow('Music APIs', 'JioSaavn + Audius'),
              const SizedBox(height: 8),
              _InfoRow('Auth & Storage', 'Firebase'),
              const SizedBox(height: 8),
              _InfoRow('Made with', '❤️ in India'),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Coming soon!',
          style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.black.withOpacity(0.85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 1200),
    ));
  }
}

// ─── SIGN OUT BUTTON ──────────────────────────────────────────

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: () => _confirmSignOut(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded,
                      color: Colors.white.withOpacity(0.8), size: 20),
                  const SizedBox(width: 10),
                  Text('Sign Out',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out of DEN?',
        confirmLabel: 'Sign Out',
        isDestructive: false,
        onConfirm: () async {
          Navigator.pop(context);
          await ref.read(authServiceProvider).signOut();
        },
      ),
    );
  }
}

// ─── DELETE ACCOUNT BUTTON ────────────────────────────────────

class _DeleteAccountButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: () => _confirmDelete(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text('Delete Account',
              style: TextStyle(
                color: Colors.red.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Account',
        message: 'This will permanently delete your account, '
            'playlists, liked songs and all your data. '
            'This action cannot be undone.',
        confirmLabel: 'Delete Account',
        isDestructive: true,
        onConfirm: () => Navigator.pop(context),
      ),
    );
  }
}

// ─── SECTION WRAPPER ──────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final int delay;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                  child: Icon(icon, color: Colors.white, size: 16)),
                const SizedBox(width: 8),
                Text(title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
              ],
            ),
          ),
          // Cards
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: children.asMap().entries.map((e) {
                    final isLast = e.key == children.length - 1;
                    return Column(
                      children: [
                        e.value,
                        if (!isLast)
                          Divider(
                            height: 1,
                            color: Colors.white.withOpacity(0.05),
                            indent: 54,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay * 60))
        .slideY(
          begin: 0.05, end: 0,
          duration: 400.ms,
          delay: Duration(milliseconds: delay * 60),
          curve: Curves.easeOutCubic);
  }
}

// ─── TILE TYPES ───────────────────────────────────────────────

// Navigation tile (tap → action/sheet)
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool isDestructive;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18)),
            const SizedBox(width: 14),
            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.red.shade400
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (value.isNotEmpty)
              Text(value,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.25), size: 18),
          ],
        ),
      ),
    );
  }
}

// Toggle switch tile
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> colors;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.pink,
            activeTrackColor: AppTheme.pink.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.4),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}

// Slider tile
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> colors;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600))),
              Text(subtitle,
                style: TextStyle(
                  color: AppTheme.pink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7),
              activeTrackColor: AppTheme.pink,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.white,
              overlayColor: AppTheme.pink.withOpacity(0.15),
            ),
            child: Slider(
              value: value, min: min, max: max,
              divisions: (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// Info tile (no tap, just displays a value)
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> colors;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600))),
          Text(value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── GLASS SHEET ──────────────────────────────────────────────

class _GlassSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SHEET OPTION ROW ─────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String? emoji;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SheetOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.emoji,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
                  AppTheme.pink.withOpacity(0.15),
                  AppTheme.purple.withOpacity(0.08),
                ])
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.pink.withOpacity(0.35)
                : Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 20))
            else if (icon != null)
              Icon(icon, color: Colors.white.withOpacity(0.5), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.pink : Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700 : FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (isSelected)
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20)),
          ],
        ),
      ),
    );
  }
}

// ─── CONFIRM DIALOG ───────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Text('Cancel',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          decoration: BoxDecoration(
                            gradient: isDestructive
                                ? const LinearGradient(colors: [
                                    Color(0xFFFF4444),
                                    Color(0xFFCC0000),
                                  ])
                                : AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(confirmLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HELPERS ──────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13)),
        Text(value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600)),
      ],
    );
  }
}