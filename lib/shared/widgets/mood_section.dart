import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';

class MoodSection extends ConsumerWidget {
  const MoodSection({super.key});

  static const List<Map<String, dynamic>> _moods = [
    {
      'label': 'Happy',
      'emoji': '😊',
      'query': 'happy bollywood songs',
      'colors': [Color(0xFFFFB3C6), Color(0xFFFFD4E8)],
      'image':
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&q=80',
    },
    {
      'label': 'Sad',
      'emoji': '💔',
      'query': 'sad hindi songs',
      'colors': [Color(0xFFB794FF), Color(0xFF8B5CF6)],
      'image':
          'https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=400&q=80',
    },
    {
      'label': 'Party',
      'emoji': '🎉',
      'query': 'party dance songs hindi',
      'colors': [Color(0xFFFF85A1), Color(0xFFFFB3C6)],
      'image':
          'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=400&q=80',
    },
    {
      'label': 'Romantic',
      'emoji': '❤️',
      'query': 'romantic hindi love songs',
      'colors': [Color(0xFFD4B8FF), Color(0xFFB794FF)],
      'image':
          'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=400&q=80',
    },
    {
      'label': 'Chill',
      'emoji': '🌙',
      'query': 'chill lofi hindi songs',
      'colors': [Color(0xFFB0C4DE), Color(0xFF8B9DC3)],
      'image':
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&q=80',
    },
    {
      'label': 'Workout',
      'emoji': '💪',
      'query': 'workout motivation songs',
      'colors': [Color(0xFFB794FF), Color(0xFFFF85A1)],
      'image':
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&q=80',
    },
    {
      'label': 'Devotional',
      'emoji': '🙏',
      'query': 'devotional bhajan songs',
      'colors': [Color(0xFFFFD700), Color(0xFFFFB347)],
      'image':
          'https://images.unsplash.com/photo-1604608672516-5b0acb1b7d69?w=400&q=80',
    },
    {
      'label': 'Punjabi',
      'emoji': '🎵',
      'query': 'punjabi hits 2025',
      'colors': [Color(0xFF8B5CF6), Color(0xFFD4B8FF)],
      'image':
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&q=80',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.mood_rounded,
                    color: Colors.white, size: 22)),
              const SizedBox(width: 8),
              const Text('Moods & Genres',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),

        // Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: _moods.length,
            itemBuilder: (context, index) => _MoodCard(
              mood: _moods[index],
              index: index,
              onTap: () {
                ref
                    .read(searchQueryProvider.notifier)
                    .state = _moods[index]['query'];
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodCard extends StatefulWidget {
  final Map<String, dynamic> mood;
  final int index;
  final VoidCallback onTap;

  const _MoodCard({
    required this.mood,
    required this.index,
    required this.onTap,
  });

  @override
  State<_MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<_MoodCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.mood['colors'] as List<Color>;
    final imageUrl = widget.mood['image'] as String;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image ──
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (ctx, _) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[0].withOpacity(0.6),
                        colors[1].withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[0].withOpacity(0.6),
                        colors[1].withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // ── Dark gradient scrim (bottom heavy for legibility) ──
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.72),
                    ],
                  ),
                ),
              ),

              // ── Coloured tint overlay ──
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors[0].withOpacity(0.22),
                      colors[1].withOpacity(0.10),
                    ],
                  ),
                ),
              ),

              // ── Subtle border ──
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors[0].withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
              ),

              // ── Content ──
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Frosted emoji pill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.mood['emoji'],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Label
                    Text(
                      widget.mood['label'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 450.ms, delay: (widget.index * 55).ms)
        .scale(
          begin: const Offset(0.88, 0.88),
          end: const Offset(1, 1),
          duration: 450.ms,
          delay: (widget.index * 55).ms,
          curve: Curves.easeOutBack,
        );
  }
}