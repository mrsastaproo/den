import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/featured_banner.dart';
import '../../shared/widgets/trending_section.dart';
import '../../shared/widgets/top_charts_section.dart';
import '../../shared/widgets/mood_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
Widget build(BuildContext context, WidgetRef ref) {
  return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          const SliverToBoxAdapter(child: FeaturedBanner()),
          const SliverToBoxAdapter(child: TrendingSection()),
          const SliverToBoxAdapter(child: TopChartsSection()),
          const SliverToBoxAdapter(child: MoodSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 200)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning!'
        : hour < 17 ? 'Good Afternoon!' : 'Good Evening!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13, fontWeight: FontWeight.w400)),
              const SizedBox(height: 2),
              const Text('DEN',
                style: TextStyle(color: Colors.white,
                  fontSize: 32, fontWeight: FontWeight.w900,
                  letterSpacing: -1.5)),
            ],
          ),
          GlassContainer(
            padding: const EdgeInsets.all(10),
            borderRadius: 14,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
              child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}