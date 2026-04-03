import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/admin_service.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        stats
            .when(
              loading: () => _shimmerGrid(),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
              data: (s) => Column(
                children: [
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Total Users',
                            value: _fmt(s.totalUsers),
                            icon: Icons.people_rounded,
                            color: const Color(0xFF6C63FF))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Active Today',
                            value: _fmt(s.activeToday),
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF11D47B))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Total Plays',
                            value: _fmt(s.totalPlays),
                            icon: Icons.play_circle_rounded,
                            color: const Color(0xFFFF3366))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Total Likes',
                            value: _fmt(s.totalLikes),
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFFFF85A1))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Playlists',
                            value: _fmt(s.totalPlaylists),
                            icon: Icons.queue_music_rounded,
                            color: const Color(0xFFFFD700))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Banned',
                            value: _fmt(s.bannedUsers),
                            icon: Icons.block_rounded,
                            color: const Color(0xFFFF4444))),
                  ]),
                  const SizedBox(height: 10),
                  _StatCard(
                    label: 'Active Announcements',
                    value: _fmt(s.activeAnnouncements),
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFFF7971E),
                    wide: true,
                  ),
                  if (s.lastUpdated != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Last updated: ${_fmtDate(s.lastUpdated!)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _shimmerGrid() {
    return Column(
        children: List.generate(
            3,
            (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                        child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                                duration: 1400.ms,
                                color:
                                    Colors.white.withOpacity(0.04))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                                duration: 1400.ms,
                                color:
                                    Colors.white.withOpacity(0.04))),
                  ]),
                )));
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool wide;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              )),
        ],
      ),
    );
  }
}
