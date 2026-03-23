// ─────────────────────────────────────────────────────────────────────────────
// settings_screen.dart  —  DEN Settings (Cleaned + Backend Wired)
//
// Sections kept:
//   1. Profile Card + Stats Row
//   2. DEN Wrapped entry
//   3. Playback  (crossfade · normalize · autoplay · gapless · lyrics · EQ)
//   4. Audio Quality  (streaming · wifi · mobile data · format)
//   5. Downloads  (quality · offline mode · data warning · clear downloads)
//   6. Language & Content  (language · explicit)
//   7. Appearance  (theme · accent color)
//   8. Social & Privacy  (private session · activity · history · analytics)
//   9. Notifications  (push toggle + sub-toggles)
//  10. Storage  (cache size · clear cache · downloaded songs info)
//  11. About  (version sheet)
//  12. Admin Panel  (admin-only, hidden otherwise)
//  13. Sign Out · Delete Account
//
// Removed (not needed for v1):
//   ✗ Car Mode          — niche feature
//   ✗ Sleep Timer       — niche feature
//   ✗ Storage Location  — "coming soon" was hardcoded
//   ✗ Content Prefs     — "coming soon" was hardcoded
//   ✗ Blocked Artists   — "coming soon" was hardcoded
//   ✗ Font Size         — over-engineering for v1
//   ✗ Animations        — over-engineering for v1
//   ✗ Album Art Style   — over-engineering for v1
//   ✗ Rate / Share DEN  — placeholder URLs
//   ✗ Report Bug        — placeholder mailto
//   ✗ Help & Support    — placeholder URL
//   ✗ Privacy Policy    — placeholder URL
//   ✗ Terms of Service  — placeholder URL
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/app_theme.dart';
import 'edit_profile_screen.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/download_service.dart';
import '../../core/services/appearance_service.dart';
import 'equalizer_screen.dart';
import 'admin_screen.dart';
import '../../core/services/player_service.dart';

// ─── SETTINGS SCREEN ──────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header()),
          SliverToBoxAdapter(child: _ProfileCard(user: user)),
          SliverToBoxAdapter(child: _StatsRow()),
          SliverToBoxAdapter(child: _WrappedEntry()),
          SliverToBoxAdapter(child: _PlaybackSection()),
          SliverToBoxAdapter(child: _AudioQualitySection()),
          SliverToBoxAdapter(child: _DownloadsSection()),
          SliverToBoxAdapter(child: _ContentSection()),
          SliverToBoxAdapter(child: _AppearanceSection()),
          SliverToBoxAdapter(child: _PrivacySection()),
          SliverToBoxAdapter(child: _NotificationsSection()),
          SliverToBoxAdapter(child: _StorageSection()),
          SliverToBoxAdapter(child: _AboutSection()),
          SliverToBoxAdapter(child: _AdminPanelEntry()),
          SliverToBoxAdapter(child: _SignOutButton()),
          SliverToBoxAdapter(child: _DeleteAccountButton()),
          SliverToBoxAdapter(
              child: SizedBox(height: kDenBottomPadding + 40)),
        ],
      ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            bottom: 16,
          ),
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
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.settings_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── PROFILE CARD ─────────────────────────────────────────────────────────────

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
              gradient: LinearGradient(colors: [
                AppTheme.pink.withOpacity(0.15),
                AppTheme.purple.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.pink.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: -5,
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.transparent,
                  child: user?.photoURL != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.photoURL,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          (user?.email?.substring(0, 1).toUpperCase()) ?? 'D',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Name + email + plan badge
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? 'Not signed in',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          Text(
                            'Free Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()),
                  );
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
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: ShaderMask(
                        shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05, end: 0);
  }
}

// ─── STATS ROW ────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedSongsProvider).value?.length ?? 0;
    final history = ref.watch(historyProvider).value?.length ?? 0;
    final playlists = ref.watch(playlistsProvider).value?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Expanded(
          child: _StatChip(
            value: '$liked',
            label: 'Liked',
            icon: Icons.favorite_rounded,
            colors: [AppTheme.pink, AppTheme.pinkDeep],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            value: '$history',
            label: 'Played',
            icon: Icons.history_rounded,
            colors: [AppTheme.purple, AppTheme.purpleDeep],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            value: '$playlists',
            label: 'Playlists',
            icon: Icons.queue_music_rounded,
            colors: [AppTheme.pinkDeep, AppTheme.purple],
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 500.ms, delay: 80.ms);
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final List<Color> colors;

  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              colors[0].withOpacity(0.15),
              colors[1].withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors[0].withOpacity(0.2)),
          ),
          child: Column(children: [
            ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: colors).createShader(b),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── WRAPPED ENTRY ────────────────────────────────────────────────────────────

class _WrappedEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/wrapped'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.pink.withOpacity(0.15),
            AppTheme.purple.withOpacity(0.1),
          ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.pink.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEN Wrapped',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your weekly & monthly music stats',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ShaderMask(
            shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ),
        ]),
      ),
    );
  }
}

// ─── 1. PLAYBACK ──────────────────────────────────────────────────────────────
// Kept: crossfade · normalize · autoplay · gapless · lyrics · EQ
// Removed: Sleep Timer · Car Mode

class _PlaybackSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossfade    = ref.watch(crossfadeEnabledProvider);
    final crossfadeDur = ref.watch(crossfadeDurationProvider);
    final normalize    = ref.watch(normalizationEnabledProvider);
    final autoplay     = ref.watch(autoplayEnabledProvider);
    final gapless      = ref.watch(gaplessPlaybackProvider);
    final lyrics       = ref.watch(showLyricsProvider);
    final eqPreset     = ref.watch(eqProvider).preset;

    return _Section(
      title: 'Playback',
      icon: Icons.play_circle_rounded,
      delay: 1,
      children: [
        // Crossfade toggle
        _SwitchTile(
          icon: Icons.shuffle_on_rounded,
          label: 'Crossfade',
          subtitle: 'Smooth transitions between songs',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          value: crossfade,
          onChanged: (v) {
            ref.read(crossfadeEnabledProvider.notifier).set(v);
            ref.read(playerServiceProvider).setCrossfade(
              enabled: v,
              duration: Duration(seconds: crossfadeDur.toInt()),
            );
            HapticFeedback.selectionClick();
          },
        ),
        // Crossfade duration slider — only visible when crossfade is on
        if (crossfade)
          _SliderTile(
            icon: Icons.linear_scale_rounded,
            label: 'Crossfade Duration',
            subtitle: '${crossfadeDur.toInt()}s',
            colors: [AppTheme.pink, AppTheme.purple],
            value: crossfadeDur,
            min: 1,
            max: 12,
            onChanged: (v) {
              ref.read(crossfadeDurationProvider.notifier).set(v);
              ref.read(playerServiceProvider).setCrossfade(
                enabled: true,
                duration: Duration(seconds: v.toInt()),
              );
            },
          ),
        // Volume normalization
        _SwitchTile(
          icon: Icons.volume_up_rounded,
          label: 'Volume Normalization',
          subtitle: 'Keep volume consistent across songs',
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          value: normalize,
          onChanged: (v) {
            ref.read(normalizationEnabledProvider.notifier).set(v);
            ref.read(playerServiceProvider).reapplyNormalization();
            HapticFeedback.selectionClick();
          },
        ),
        // Autoplay
        _SwitchTile(
          icon: Icons.skip_next_rounded,
          label: 'Autoplay',
          subtitle: 'Continue with similar songs when queue ends',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          value: autoplay,
          onChanged: (v) {
            ref.read(autoplayEnabledProvider.notifier).set(v);
            HapticFeedback.selectionClick();
          },
        ),
        // Gapless playback
        _SwitchTile(
          icon: Icons.queue_music_rounded,
          label: 'Gapless Playback',
          subtitle: 'No silence between tracks',
          colors: [AppTheme.pink, AppTheme.purple],
          value: gapless,
          onChanged: (v) {
            ref.read(gaplessPlaybackProvider.notifier).set(v);
            ref.read(playerServiceProvider).setGapless(v);
            HapticFeedback.selectionClick();
          },
        ),
        // Show lyrics
        _SwitchTile(
          icon: Icons.lyrics_rounded,
          label: 'Show Lyrics',
          subtitle: 'Display lyrics in player when available',
          colors: [AppTheme.purple, AppTheme.pinkDeep],
          value: lyrics,
          onChanged: (v) {
            ref.read(showLyricsProvider.notifier).set(v);
            HapticFeedback.selectionClick();
          },
        ),
        // Equalizer → navigate to EQ screen
        _NavTile(
          icon: Icons.equalizer_rounded,
          label: 'Equalizer',
          subtitle: 'Fine-tune your sound',
          value: eqPreset,
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EqualizerScreen()),
          ),
        ),
      ],
    );
  }
}

// ─── 2. AUDIO QUALITY ─────────────────────────────────────────────────────────

class _AudioQualitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamQ = ref.watch(streamingQualityProvider);
    final wifiQ   = ref.watch(wifiQualityProvider);
    final mobileQ = ref.watch(mobileDataQualityProvider);
    final format  = ref.watch(audioFormatProvider);

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
          onTap: () => _showQualitySheet(context, 'Streaming', streamQ,
              (q) => ref.read(streamingQualityProvider.notifier).set(q)),
        ),
        _NavTile(
          icon: Icons.wifi_rounded,
          label: 'WiFi Quality',
          subtitle: 'Use higher quality on WiFi',
          value: wifiQ,
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          onTap: () => _showWifiQualitySheet(context, ref, wifiQ),
        ),
        _NavTile(
          icon: Icons.signal_cellular_alt_rounded,
          label: 'Mobile Data Quality',
          subtitle: 'Reduce quality to save data',
          value: mobileQ,
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => _showQualitySheet(context, 'Mobile Data', mobileQ,
              (q) => ref.read(mobileDataQualityProvider.notifier).set(q)),
        ),
        _NavTile(
          icon: Icons.headphones_rounded,
          label: 'Audio Format',
          subtitle: 'MP3, AAC, or FLAC when available',
          value: format,
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () => _showFormatSheet(context, ref, format),
        ),
      ],
    );
  }

  void _showQualitySheet(BuildContext context, String type, String current,
      Function(String) onSelect) {
    final qualities = [
      {'value': '96kbps',  'label': 'Low',    'desc': 'Saves the most data'},
      {'value': '160kbps', 'label': 'Normal', 'desc': 'Good balance'},
      {'value': '320kbps', 'label': 'High',   'desc': 'Best quality'},
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
            return _SheetOption(
              label: q['value']!,
              subtitle: '${q['label']} • ${q['desc']}',
              icon: Icons.high_quality_rounded,
              isSelected: q['value'] == current,
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

  void _showWifiQualitySheet(
      BuildContext context, WidgetRef ref, String current) {
    final opts = [
      {'value': 'Auto',    'desc': 'Match streaming quality setting'},
      {'value': '320kbps', 'desc': 'Always use highest quality on WiFi'},
      {'value': '160kbps', 'desc': 'Medium quality on WiFi'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'WiFi Quality',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: opts.length,
          itemBuilder: (_, i) {
            final q = opts[i];
            return _SheetOption(
              label: q['value']!,
              subtitle: q['desc']!,
              icon: Icons.wifi_rounded,
              isSelected: q['value'] == current,
              onTap: () {
                ref.read(wifiQualityProvider.notifier).set(q['value']!);
                Navigator.pop(context);
                HapticFeedback.selectionClick();
              },
            );
          },
        ),
      ),
    );
  }

  void _showFormatSheet(
      BuildContext context, WidgetRef ref, String current) {
    final formats = [
      {'value': 'MP3',  'desc': 'Widely compatible, good quality'},
      {'value': 'AAC',  'desc': 'Better quality at lower bitrates'},
      {'value': 'FLAC', 'desc': 'Lossless — largest file sizes'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Audio Format',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: formats.length,
          itemBuilder: (_, i) {
            final f = formats[i];
            return _SheetOption(
              label: f['value']!,
              subtitle: f['desc']!,
              icon: Icons.headphones_rounded,
              isSelected: f['value'] == current,
              onTap: () {
                ref.read(audioFormatProvider.notifier).set(f['value']!);
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

// ─── 3. DOWNLOADS ─────────────────────────────────────────────────────────────
// Removed: Storage Location (was "coming soon" hardcoded)

class _DownloadsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlQ        = ref.watch(downloadQualityProvider);
    final offline    = ref.watch(offlineModeProvider);
    final dataWarn   = ref.watch(dataWarningProvider);
    final stats      = ref.watch(storageStatsProvider);
    final dlCount    = stats.value?.downloadedSongCount ?? 0;

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
            ref.read(offlineModeProvider.notifier).set(v);
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
            ref.read(dataWarningProvider.notifier).set(v);
            HapticFeedback.selectionClick();
          },
        ),
        _NavTile(
          icon: Icons.delete_sweep_rounded,
          label: 'Clear Downloads',
          subtitle: '$dlCount songs downloaded',
          value: '',
          colors: [AppTheme.pinkDeep, AppTheme.pink],
          onTap: () => _showClearDownloadsDialog(context, ref),
          isDestructive: true,
        ),
      ],
    );
  }

  void _showDlQualitySheet(
      BuildContext context, WidgetRef ref, String current) {
    final qualities = [
      {'value': '96kbps',  'label': 'Low',    'desc': 'Uses less storage'},
      {'value': '160kbps', 'label': 'Normal', 'desc': 'Balanced'},
      {'value': '320kbps', 'label': 'High',   'desc': 'Best quality'},
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
            return _SheetOption(
              label: q['value']!,
              subtitle: '${q['label']} • ${q['desc']}',
              icon: Icons.download_rounded,
              isSelected: q['value'] == current,
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

  void _showClearDownloadsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Clear Downloads',
        message:
            'This will remove all downloaded songs from your device.',
        confirmLabel: 'Clear',
        isDestructive: true,
        onConfirm: () async {
          await ref.read(storageServiceProvider).clearDownloads();
          await ref.read(downloadServiceProvider).clearAllDownloads();
          ref.invalidate(storageStatsProvider);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }
}

// ─── 4. LANGUAGE & CONTENT ────────────────────────────────────────────────────
// Removed: Content Preferences (coming soon), Blocked Artists (coming soon)

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
            ref.read(explicitContentProvider.notifier).set(v);
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }

  void _showLanguageSheet(
      BuildContext context, WidgetRef ref, String current) {
    final langs = [
      {'value': 'Hindi + English', 'emoji': '🌍'},
      {'value': 'Hindi',           'emoji': '🇮🇳'},
      {'value': 'English',         'emoji': '🇬🇧'},
      {'value': 'Punjabi',         'emoji': '🎵'},
      {'value': 'Tamil',           'emoji': '🎶'},
      {'value': 'Telugu',          'emoji': '🎸'},
      {'value': 'Marathi',         'emoji': '🎺'},
      {'value': 'Bengali',         'emoji': '🎻'},
      {'value': 'All Languages',   'emoji': '🌏'},
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
            return _SheetOption(
              label: l['value']!,
              emoji: l['emoji'],
              isSelected: l['value'] == current,
              onTap: () {
                ref
                    .read(musicLanguageProvider.notifier)
                    .set(l['value']!);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── 5. APPEARANCE ────────────────────────────────────────────────────────────
// Kept: Theme · Accent Color
// Removed: Font Size · Animations · Album Art Style (over-engineering for v1)

class _AppearanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(appearanceProvider);

    return _Section(
      title: 'Appearance',
      icon: Icons.palette_rounded,
      delay: 5,
      children: [
        _NavTile(
          icon: Icons.dark_mode_rounded,
          label: 'Theme',
          subtitle: 'App color scheme',
          value: ap.themeLabel,
          colors: [AppTheme.purple, AppTheme.purpleDeep],
          onTap: () => _showThemeSheet(context, ref, ap.theme),
        ),
        _NavTile(
          icon: Icons.color_lens_rounded,
          label: 'Accent Color',
          subtitle: 'Primary highlight color',
          value: ap.palette.label,
          colors: [AppTheme.pink, AppTheme.purple],
          onTap: () => _showColorSheet(context, ref, ap.accentColor),
        ),
      ],
    );
  }

  void _showThemeSheet(
      BuildContext context, WidgetRef ref, String current) {
    final themes = [
      {'value': 'dark',   'label': 'Dark'},
      {'value': 'amoled', 'label': 'Pure Black (AMOLED)'},
      {'value': 'auto',   'label': 'Auto (System)'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Theme',
        child: Column(
          children: themes
              .map((t) => _SheetOption(
                    label: t['label']!,
                    icon: Icons.dark_mode_rounded,
                    isSelected: t['value'] == current,
                    onTap: () {
                      ref
                          .read(appearanceProvider.notifier)
                          .setTheme(t['value']!);
                      Navigator.pop(context);
                      HapticFeedback.selectionClick();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showColorSheet(
      BuildContext context, WidgetRef ref, String currentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Accent Color',
        child: Column(
          children: allPalettes.map((p) {
            return GestureDetector(
              onTap: () {
                ref
                    .read(appearanceProvider.notifier)
                    .setAccentColor(p.id);
                Navigator.pop(context);
                HapticFeedback.selectionClick();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: p.id == currentId
                        ? p.color1.withOpacity(0.5)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: p.gradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    p.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (p.id == currentId)
                    ShaderMask(
                      shaderCallback: (b) =>
                          p.gradient.createShader(b),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20),
                    ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── 6. SOCIAL & PRIVACY ──────────────────────────────────────────────────────
// Kept: Private Session · Show Activity · Clear History · Analytics
// Removed: Privacy Policy URL · Terms URL (placeholder)

class _PrivacySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privateSession  = ref.watch(privateSessionProvider);
    final activityVisible = ref.watch(activityVisibleProvider);

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
            ref.read(privateSessionProvider.notifier).set(v);
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
        _SwitchTile(
          icon: Icons.people_rounded,
          label: 'Show Activity to Friends',
          subtitle: 'Let friends see what you\'re listening to',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          value: activityVisible,
          onChanged: (v) {
            ref.read(activityVisibleProvider.notifier).set(v);
            HapticFeedback.selectionClick();
          },
        ),
        _NavTile(
          icon: Icons.history_rounded,
          label: 'Clear Listening History',
          subtitle: 'Remove all songs from recent history',
          value: '',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showClearHistoryDialog(context, ref),
          isDestructive: true,
        ),
        _NavTile(
          icon: Icons.manage_accounts_rounded,
          label: 'Privacy Settings',
          subtitle: 'Control what data DEN collects',
          value: '',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
          onTap: () => _showPrivacySheet(context, ref),
        ),
      ],
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Clear Listening History',
        message:
            'This will remove all songs from your recent history. This cannot be undone.',
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

  void _showPrivacySheet(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(analyticsEnabledProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GlassSheet(
        title: 'Privacy Settings',
        child: StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InfoRow('Data Collection',
                    'Minimal — only what\'s needed'),
                const SizedBox(height: 12),
                const _InfoRow(
                    'Third Parties', 'JioSaavn API, Firebase'),
                const SizedBox(height: 12),
                const _InfoRow(
                    'Data Storage', 'Encrypted on Firebase'),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anonymous Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Help improve DEN with usage data',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: analytics,
                    onChanged: (v) {
                      ref
                          .read(analyticsEnabledProvider.notifier)
                          .set(v);
                      setState(() {});
                    },
                    activeColor: AppTheme.pink,
                  ),
                ]),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── 7. NOTIFICATIONS ─────────────────────────────────────────────────────────

class _NotificationsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs          = ref.watch(showNotificationsProvider);
    final newReleases     = ref.watch(notifNewReleasesProvider);
    final recommendations = ref.watch(notifRecommendationsProvider);
    final appUpdates      = ref.watch(notifAppUpdatesProvider);

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
            ref.read(showNotificationsProvider.notifier).set(v);
            HapticFeedback.selectionClick();
          },
        ),
        if (notifs) ...[
          _SwitchTile(
            icon: Icons.new_releases_rounded,
            label: 'New Releases',
            subtitle: 'When artists you follow drop new music',
            colors: [AppTheme.purple, AppTheme.purpleDeep],
            value: newReleases,
            onChanged: (v) {
              ref.read(notifNewReleasesProvider.notifier).set(v);
              HapticFeedback.selectionClick();
            },
          ),
          _SwitchTile(
            icon: Icons.recommend_rounded,
            label: 'Recommendations',
            subtitle: 'Personalized music suggestions',
            colors: [AppTheme.pinkDeep, AppTheme.purple],
            value: recommendations,
            onChanged: (v) {
              ref.read(notifRecommendationsProvider.notifier).set(v);
              HapticFeedback.selectionClick();
            },
          ),
          _SwitchTile(
            icon: Icons.update_rounded,
            label: 'App Updates',
            subtitle: 'New features and improvements',
            colors: [AppTheme.pink, AppTheme.purple],
            value: appUpdates,
            onChanged: (v) {
              ref.read(notifAppUpdatesProvider.notifier).set(v);
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ],
    );
  }
}

// ─── 8. STORAGE & DATA ────────────────────────────────────────────────────────

class _StorageSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats    = ref.watch(storageStatsProvider);
    final cacheSize = stats.value?.cacheSizeFormatted   ?? '…';
    final dlSongs  = stats.value?.downloadedSongCount   ?? 0;
    final dlSize   = stats.value?.downloadSizeFormatted ?? '…';

    return _Section(
      title: 'Storage & Data',
      icon: Icons.storage_rounded,
      delay: 8,
      children: [
        _InfoTile(
          icon: Icons.storage_rounded,
          label: 'Cache Size',
          value: cacheSize,
          colors: [AppTheme.purple, AppTheme.purpleDeep],
        ),
        _NavTile(
          icon: Icons.cleaning_services_rounded,
          label: 'Clear Cache',
          subtitle: 'Free up space from temporary files',
          value: '',
          colors: [AppTheme.pink, AppTheme.pinkDeep],
          onTap: () => _showClearCacheDialog(context, ref),
        ),
        _InfoTile(
          icon: Icons.download_done_rounded,
          label: 'Downloaded Songs',
          value: '$dlSongs songs • $dlSize',
          colors: [AppTheme.pinkDeep, AppTheme.purple],
        ),
      ],
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Clear Cache',
        message:
            'This will clear cached images and data. App performance may temporarily be slower.',
        confirmLabel: 'Clear Cache',
        isDestructive: false,
        onConfirm: () async {
          await ref.read(storageServiceProvider).clearCache();
          ref.invalidate(storageStatsProvider);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
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

// ─── 9. ABOUT ─────────────────────────────────────────────────────────────────
// Kept: version info sheet only
// Removed: Rate DEN · Share DEN · Report Bug · Help & Support (all placeholder URLs)

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
          child: Column(children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: const Text(
                'DEN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'Your music, your world.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            const _InfoRow('Built with', 'Flutter 3.x'),
            const SizedBox(height: 8),
            const _InfoRow('Music API', 'JioSaavn'),
            const SizedBox(height: 8),
            const _InfoRow('Auth & Storage', 'Firebase'),
            const SizedBox(height: 8),
            const _InfoRow('Made with', '❤️ in India'),
          ]),
        ),
      ),
    );
  }
}

// ─── ADMIN PANEL ENTRY ────────────────────────────────────────────────────────

class _AdminPanelEntry extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminScreen()));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3366), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3366).withOpacity(0.35),
                    blurRadius: 24,
                    spreadRadius: -6,
                  )
                ],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Full control over DEN',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white, size: 20),
              ]),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 450.ms)
        .slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 450.ms);
  }
}

// ─── SIGN OUT BUTTON ──────────────────────────────────────────────────────────

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
                border:
                    Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded,
                      color: Colors.white.withOpacity(0.8), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out of DEN?',
        confirmLabel: 'Sign Out',
        isDestructive: false,
        onConfirm: () async {
          Navigator.pop(dialogContext);
          await Future.delayed(const Duration(milliseconds: 300));
          await ref.read(authServiceProvider).signOut();
        },
      ),
    );
  }
}

// ─── DELETE ACCOUNT BUTTON ────────────────────────────────────────────────────

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
            child: Text(
              'Delete Account',
              style: TextStyle(
                color: Colors.red.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Delete Account',
        message:
            'This will permanently delete your account, playlists, liked songs and all your data. This action cannot be undone.',
        confirmLabel: 'Delete Account',
        isDestructive: true,
        onConfirm: () async {
          try {
            await ref.read(authServiceProvider).deleteAccount();
          } catch (e) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red.shade900,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ]),
                ),
                Divider(
                    color: Colors.white.withOpacity(0.06), height: 1),
                ...children,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            duration: 400.ms,
            delay: Duration(milliseconds: delay * 60))
        .slideY(
            begin: 0.04,
            end: 0,
            duration: 400.ms,
            delay: Duration(milliseconds: delay * 60));
  }
}

// ─── _SwitchTile ──────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.pink,
        activeTrackColor: AppTheme.pink.withOpacity(0.3),
        inactiveThumbColor: Colors.white.withOpacity(0.4),
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    );
  }
}

// ─── _NavTile ─────────────────────────────────────────────────────────────────

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
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: isDestructive
                  ? const LinearGradient(
                      colors: [Color(0xFFFF4444), Color(0xFFCC2222)])
                  : LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDestructive
                        ? const Color(0xFFFF6666)
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.25),
            size: 18,
          ),
        ]),
      ),
    );
  }
}

// ─── _InfoTile ────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }
}

// ─── _SliderTile ──────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.pink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppTheme.pink,
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  thumbColor: Colors.white,
                  overlayColor: AppTheme.pink.withOpacity(0.2),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── _GlassSheet ──────────────────────────────────────────────────────────────

class _GlassSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _GlassSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ]),
              ),
              Divider(
                  color: Colors.white.withOpacity(0.08), height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _SheetOption ─────────────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String? emoji;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SheetOption({
    required this.label,
    this.subtitle,
    this.emoji,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.pink.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.pink.withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 20))
          else if (icon != null)
            ShaderMask(
              shaderCallback: (b) => (isSelected
                      ? AppTheme.primaryGradient
                      : LinearGradient(colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.4),
                        ]))
                  .createShader(b),
              child:
                  Icon(icon, color: Colors.white, size: 20),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color:
                        isSelected ? AppTheme.pink : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isSelected)
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
            ),
        ]),
      ),
    );
  }
}

// ─── _ConfirmDialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatefulWidget {
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
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _loading = false;

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
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              try {
                                widget.onConfirm();
                              } finally {
                                if (mounted) {
                                  setState(() => _loading = false);
                                }
                              }
                            },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: widget.isDestructive
                              ? const LinearGradient(colors: [
                                  Color(0xFFFF4444),
                                  Color(0xFFCC0000),
                                ])
                              : AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.confirmLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _InfoRow ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}