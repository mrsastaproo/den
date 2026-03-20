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
import '../../core/services/profile_service.dart';
import '../../core/providers/music_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(context, ref, user),
          ),

          // Profile Card
          SliverToBoxAdapter(
            child: _ProfileCard(user: user),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: _StatsRow(ref: ref),
          ),

          // Settings sections
          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Music',
              icon: Icons.music_note_rounded,
              items: [
                _SettingsItem(
                  icon: Icons.high_quality_rounded,
                  label: 'Streaming Quality',
                  value: '320kbps',
                  colors: [AppTheme.pink, AppTheme.pinkDeep],
                  onTap: () => _showQualitySheet(context),
                ),
                _SettingsItem(
                  icon: Icons.download_rounded,
                  label: 'Download Quality',
                  value: '320kbps',
                  colors: [AppTheme.purple, AppTheme.purpleDeep],
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.equalizer_rounded,
                  label: 'Equalizer',
                  value: 'Normal',
                  colors: [AppTheme.pinkDeep, AppTheme.purple],
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.language_rounded,
                  label: 'Music Language',
                  value: 'Hindi + English',
                  colors: [AppTheme.pink, AppTheme.purple],
                  onTap: () => _showLanguageSheet(context),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Appearance',
              icon: Icons.palette_rounded,
              items: [
                _SettingsItem(
                  icon: Icons.dark_mode_rounded,
                  label: 'Theme',
                  value: 'Dark',
                  colors: [AppTheme.purple, AppTheme.purpleDeep],
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.color_lens_rounded,
                  label: 'Accent Color',
                  value: 'Pink + Purple',
                  colors: [AppTheme.pink, AppTheme.purple],
                  onTap: () => _showColorSheet(context),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Account',
              icon: Icons.person_rounded,
              items: [
                _SettingsItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  value: 'On',
                  colors: [AppTheme.pink, AppTheme.pinkDeep],
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.privacy_tip_rounded,
                  label: 'Privacy Policy',
                  value: '',
                  colors: [AppTheme.purple, AppTheme.purpleDeep],
                  onTap: () {},
                ),
                _SettingsItem(
                  icon: Icons.info_rounded,
                  label: 'About DEN',
                  value: 'v1.0.0',
                  colors: [AppTheme.pinkDeep, AppTheme.purple],
                  onTap: () => _showAboutSheet(context),
                ),
              ],
            ),
          ),

          // Logout button
          SliverToBoxAdapter(
            child: _LogoutButton(ref: ref, context: context),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 200)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, user) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20, right: 20, bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.5),
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
                style: TextStyle(color: Colors.white,
                  fontSize: 26, fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showQualitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Streaming Quality',
        child: Column(
          children: ['96kbps', '160kbps', '320kbps'].map((q) =>
            ListTile(
              title: Text(q,
                style: const TextStyle(color: Colors.white)),
              trailing: q == '320kbps'
                ? ShaderMask(
                    shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                    child: const Icon(Icons.check_rounded,
                      color: Colors.white))
                : null,
              onTap: () => Navigator.pop(context),
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Music Language',
        child: Column(
          children: [
            'Hindi', 'English', 'Punjabi',
            'Tamil', 'Telugu', 'All Languages'
          ].map((lang) => ListTile(
            title: Text(lang,
              style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          )).toList(),
        ),
      ),
    );
  }

  void _showColorSheet(BuildContext context) {
    final themes = [
      {'name': 'Pink + Purple', 'c1': AppTheme.pink,
        'c2': AppTheme.purple},
      {'name': 'Red + Orange', 'c1': const Color(0xFFFF6B6B),
        'c2': const Color(0xFFFFB347)},
      {'name': 'Blue + Cyan', 'c1': const Color(0xFF6BB8FF),
        'c2': const Color(0xFF47FFD4)},
      {'name': 'Green + Teal', 'c1': const Color(0xFF6BFF8C),
        'c2': const Color(0xFF47FFD4)},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'Accent Color',
        child: Column(
          children: themes.map((t) => ListTile(
            leading: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  t['c1'] as Color, t['c2'] as Color]),
                shape: BoxShape.circle)),
            title: Text(t['name'] as String,
              style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          )).toList(),
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlassSheet(
        title: 'About DEN',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
                child: const Text('DEN',
                  style: TextStyle(color: Colors.white,
                    fontSize: 48, fontWeight: FontWeight.w900,
                    letterSpacing: -2)),
              ),
              const SizedBox(height: 8),
              Text('Version 1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14)),
              const SizedBox(height: 8),
              Text('Your music, your world.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              Text('Built with ❤️ using Flutter\nPowered by JioSaavn + Audius',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13)),
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
                  AppTheme.purple.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
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
                          user?.email?.substring(0, 1)
                            .toUpperCase() ?? 'D',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                  ),
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ??
                          user?.email?.split('@')[0] ?? 'DEN User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? 'music lover',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13)),
                      const SizedBox(height: 10),
                      // Premium badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.pink.withOpacity(0.3),
                              blurRadius: 10, spreadRadius: -3),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                              color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Free User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit button
                GestureDetector(
                  onTap: () {},
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 10, sigmaY: 10),
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
    ).animate()
      .fadeIn(duration: 500.ms)
      .slideY(begin: -0.1, end: 0,
        duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

// ─── STATS ROW ────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final WidgetRef ref;
  const _StatsRow({required this.ref});

  @override
  Widget build(BuildContext context) {
    final likedCount =
      ref.watch(likedSongsProvider).value?.length ?? 0;
    final historyCount =
      ref.watch(historyProvider).value?.length ?? 0;
    final playlistCount =
      ref.watch(playlistsProvider).value?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: _StatItem(
            value: '$likedCount',
            label: 'Liked',
            icon: Icons.favorite_rounded,
            colors: [AppTheme.pink, AppTheme.pinkDeep],
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatItem(
            value: '$historyCount',
            label: 'Played',
            icon: Icons.history_rounded,
            colors: [AppTheme.purple, AppTheme.purpleDeep],
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatItem(
            value: '$playlistCount',
            label: 'Playlists',
            icon: Icons.queue_music_rounded,
            colors: [AppTheme.pinkDeep, AppTheme.purple],
          )),
        ],
      ),
    ).animate()
      .fadeIn(duration: 500.ms, delay: 100.ms)
      .slideY(begin: 0.1, end: 0, duration: 500.ms,
        delay: 100.ms, curve: Curves.easeOutCubic);
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final List<Color> colors;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors[0].withOpacity(0.15),
                colors[1].withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors[0].withOpacity(0.2)),
          ),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: colors).createShader(b),
                child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(height: 8),
              Text(value,
                style: TextStyle(
                  color: colors[0],
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
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

// ─── SETTINGS SECTION ─────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_SettingsItem> items;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                  child: Icon(icon, color: Colors.white, size: 16)),
                const SizedBox(width: 6),
                Text(title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
              ],
            ),
          ),

          // Items
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.07),
                      Colors.white.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                    indent: 56, endIndent: 16),
                  itemBuilder: (_, i) => items[i],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 150.ms)
      .slideY(begin: 0.1, end: 0, duration: 400.ms,
        delay: 150.ms, curve: Curves.easeOutCubic);
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withOpacity(0.3),
                    blurRadius: 8, spreadRadius: -2),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
            ),
            // Value + arrow
            if (value.isNotEmpty)
              Text(value,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── LOGOUT BUTTON ────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final WidgetRef ref;
  final BuildContext context;

  const _LogoutButton({
    required this.ref,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.15),
                    Colors.red.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  const Text('Sign Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 300.ms);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
          style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5)))),
          ElevatedButton(
onPressed: () async {
  Navigator.pop(context);
  ref.invalidate(trendingProvider);
  ref.invalidate(newReleasesProvider);
  ref.invalidate(topChartsProvider);
  ref.invalidate(searchQueryProvider);
  ref.invalidate(currentSongProvider);
  await ref.read(authServiceProvider).signOut();
},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: const Text('Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── GLASS SHEET ──────────────────────────────────────────────

class _GlassSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _GlassSheet({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
              ),
              child,
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}