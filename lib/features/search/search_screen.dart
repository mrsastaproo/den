import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/queue_meta.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

// ─── PROVIDERS ────────────────────────────────────────────────

final searchFilterProvider = StateProvider<String>((ref) => 'All');

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
        (ref) => RecentSearchesNotifier());

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getStringList('recent_searches') ?? [];
  }

  Future<void> add(String q) async {
    if (q.trim().isEmpty) return;
    final updated =
        [q.trim(), ...state.where((s) => s != q.trim())].take(20).toList();
    state = updated;
    final p = await SharedPreferences.getInstance();
    await p.setStringList('recent_searches', updated);
  }

  Future<void> remove(String q) async {
    state = state.where((s) => s != q).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('recent_searches', state);
  }

  Future<void> clear() async {
    state = [];
    final p = await SharedPreferences.getInstance();
    await p.remove('recent_searches');
  }
}

// ─── SEARCH SCREEN ────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollController = ScrollController();
  bool _focused = false;
  bool _scrolled = false;

  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    _scrollController.addListener(() {
      final s = _scrollController.offset > 10;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _search(String q) {
    _ctrl.text = q;
    ref.read(searchQueryProvider.notifier).state = q;
    if (q.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(q.trim());
    }
  }

  void _clear() {
    _ctrl.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final filter = ref.watch(searchFilterProvider);
    final recents = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
          children: [
            // ── Ambient background orbs ──
            _AmbientOrbs(pulseController: _pulseController, waveController: _waveController),

            // ── Main content ──
            Column(
              children: [
                _PremiumSearchHeader(
                  ctrl: _ctrl,
                  focus: _focus,
                  focused: _focused,
                  scrolled: _scrolled,
                  query: query,
                  onChanged: (q) =>
                      ref.read(searchQueryProvider.notifier).state = q,
                  onSubmit: (q) {
                    _search(q);
                    FocusScope.of(context).unfocus();
                  },
                  onClear: _clear,
                ),

                if (query.isNotEmpty)
                  _PremiumFilterChips(
                    selected: filter,
                    onSelect: (f) {
                      HapticFeedback.selectionClick();
                      ref.read(searchFilterProvider.notifier).state = f;
                    },
                  ),

                Expanded(
                  child: query.isEmpty
                      ? _PremiumEmptyState(
                          recents: recents,
                          scrollController: _scrollController,
                          onRecentTap: (q) {
                            _search(q);
                            FocusScope.of(context).unfocus();
                          },
                          onRecentRemove: (q) => ref
                              .read(recentSearchesProvider.notifier)
                              .remove(q),
                          onClearAll: () =>
                              ref.read(recentSearchesProvider.notifier).clear(),
                          onCategoryTap: (cat) {
                            _search(cat);
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : _PremiumResultsBody(
                          results: results,
                          filter: filter,
                          query: query,
                          scrollController: _scrollController,
                        ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

// ─── AMBIENT ORBS BACKGROUND ─────────────────────────────────

class _AmbientOrbs extends StatelessWidget {
  final AnimationController pulseController;
  final AnimationController waveController;
  const _AmbientOrbs({required this.pulseController, required this.waveController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseController, waveController]),
      builder: (_, __) {
        final p = pulseController.value;
        final w = waveController.value;
        return Stack(
          children: [
            // Top-left pink orb
            Positioned(
              top: -80 + (p * 20),
              left: -60 + (math.sin(w * math.pi * 2) * 15),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.pink.withOpacity(0.18 + p * 0.06),
                      AppTheme.pink.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Top-right purple orb
            Positioned(
              top: 60 + (math.cos(w * math.pi * 2) * 20),
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.purple.withOpacity(0.14 + p * 0.05),
                      AppTheme.purple.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Mid subtle orb
            Positioned(
              top: 340,
              left: 100,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.pinkDeep.withOpacity(0.07 + p * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── PREMIUM SEARCH HEADER ───────────────────────────────────

class _PremiumSearchHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool focused;
  final bool scrolled;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  const _PremiumSearchHeader({
    required this.ctrl,
    required this.focus,
    required this.focused,
    required this.scrolled,
    required this.query,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(scrolled ? 0.75 : 0.55),
                Colors.black.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: scrolled
                    ? Colors.white.withOpacity(0.06)
                    : Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: focused
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            // Animated sound wave icon
                            _SoundWaveIcon(),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Discover',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    height: 1.0,
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      AppTheme.primaryGradient.createShader(b),
                                  child: const Text(
                                    "music you'll love",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ).animate().fadeIn(duration: 350.ms).slideY(
                              begin: -0.15,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ),
              ),

              // Search bar
              Row(
                children: [
                  Expanded(
                    child: _GlassSearchBar(
                      ctrl: ctrl,
                      focus: focus,
                      focused: focused,
                      query: query,
                      onChanged: onChanged,
                      onSubmit: onSubmit,
                      onClear: onClear,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: focused
                        ? Row(
                            children: [
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  if (query.isEmpty) onClear();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: AppTheme.pink.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(duration: 200.ms).slideX(
                                    begin: 0.3,
                                    end: 0,
                                    duration: 200.ms,
                                  ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ANIMATED SOUND WAVE ICON ────────────────────────────────

class _SoundWaveIcon extends StatefulWidget {
  @override
  State<_SoundWaveIcon> createState() => _SoundWaveIconState();
}

class _SoundWaveIconState extends State<_SoundWaveIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.pink.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _WavePainter(_ctrl.value),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final bars = 5;
    final barW = 2.2;
    final gap = (size.width - bars * barW) / (bars + 1);
    final heights = [0.3, 0.65, 1.0, 0.65, 0.3];

    for (int i = 0; i < bars; i++) {
      final phase = (t - i * 0.15) % 1.0;
      final wave = math.sin(phase * math.pi * 2);
      final h = heights[i] * (0.4 + 0.6 * ((wave + 1) / 2)) * size.height * 0.65;
      final x = gap + i * (barW + gap) + barW / 2;
      final cy = size.height / 2;
      canvas.drawLine(
        Offset(x, cy - h / 2),
        Offset(x, cy + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

// ─── GLASS SEARCH BAR ────────────────────────────────────────

class _GlassSearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool focused;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  const _GlassSearchBar({
    required this.ctrl,
    required this.focus,
    required this.focused,
    required this.query,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused
              ? AppTheme.pink.withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
          width: focused ? 1.5 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppTheme.pink.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: AppTheme.purple.withOpacity(0.1),
                  blurRadius: 32,
                  spreadRadius: -8,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: Colors.white.withOpacity(focused ? 0.09 : 0.06),
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              onChanged: onChanged,
              onSubmitted: onSubmit,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              cursorColor: AppTheme.pink,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                hintText: 'Songs, artists, albums, moods…',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  padding: const EdgeInsets.all(14),
                  child: ShaderMask(
                    shaderCallback: (b) => (focused
                            ? AppTheme.primaryGradient
                            : LinearGradient(colors: [
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.3),
                              ]))
                        .createShader(b),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(
                        onTap: onClear,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.6),
                            size: 14,
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PREMIUM FILTER CHIPS ─────────────────────────────────────

class _PremiumFilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _PremiumFilterChips(
      {required this.selected, required this.onSelect});

  static const _filters = ['All', 'Songs', 'Artists', 'Albums'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final sel = f == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: sel ? AppTheme.primaryGradient : null,
                  color: sel ? null : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: sel
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: AppTheme.pink.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: -3,
                          )
                        ]
                      : [],
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color: sel
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: sel ? 0.3 : 0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

// ─── PREMIUM EMPTY STATE ─────────────────────────────────────

class _PremiumEmptyState extends StatefulWidget {
  final List<String> recents;
  final ScrollController scrollController;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final VoidCallback onClearAll;
  final ValueChanged<String> onCategoryTap;

  const _PremiumEmptyState({
    required this.recents,
    required this.scrollController,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onClearAll,
    required this.onCategoryTap,
  });

  @override
  State<_PremiumEmptyState> createState() => _PremiumEmptyStateState();
}

class _PremiumEmptyStateState extends State<_PremiumEmptyState> {
  bool _showAllRecents = false;

  @override
  Widget build(BuildContext context) {
    final displayedRecents = _showAllRecents
        ? widget.recents
        : widget.recents.take(5).toList();

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      children: [
        // Recent searches
        if (widget.recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Recent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ]),
                GestureDetector(
                  onTap: widget.onClearAll,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: AppTheme.pink.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...displayedRecents.asMap().entries.map((e) => _PremiumRecentTile(
                query: e.value,
                onTap: () => widget.onRecentTap(e.value),
                onRemove: () => widget.onRecentRemove(e.value),
              ).animate().fadeIn(
                    delay: Duration(milliseconds: e.key * 40),
                    duration: 300.ms,
                  ).slideX(
                    begin: -0.04,
                    end: 0,
                    delay: Duration(milliseconds: e.key * 40),
                    duration: 300.ms,
                    curve: Curves.easeOutCubic,
                  )),
          
          if (widget.recents.length > 5)
            GestureDetector(
              onTap: () => setState(() => _showAllRecents = !_showAllRecents),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAllRecents ? 'Show less' : 'See more',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllRecents
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),
          Divider(
            color: Colors.white.withOpacity(0.05),
            indent: 20,
            endIndent: 20,
          ),
        ],

        // Browse section
        _PremiumBrowseSection(onTap: widget.onCategoryTap),
        const SizedBox(height: 160),
      ],
    );
  }
}

class _PremiumRecentTile extends StatefulWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PremiumRecentTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_PremiumRecentTile> createState() => _PremiumRecentTileState();
}

class _PremiumRecentTileState extends State<_PremiumRecentTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(_pressed ? 0.1 : 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Icon(
                Icons.history_rounded,
                color: Colors.white.withOpacity(0.35),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.query,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.north_west_rounded,
                  color: Colors.white.withOpacity(0.25),
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PREMIUM BROWSE SECTION ───────────────────────────────────

class _PremiumBrowseSection extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _PremiumBrowseSection({required this.onTap});

  static const _cats = [
    {
      'label': 'Bollywood',
      'sub': 'Hindi Films',
      'icon': Icons.movie_creation_outlined,
      'c1': Color(0xFFFF6B6B),
      'c2': Color(0xFFFF8E53),
    },
    {
      'label': 'Punjabi',
      'sub': 'Desi Beats',
      'icon': Icons.graphic_eq_rounded,
      'c1': Color(0xFF9B59B6),
      'c2': Color(0xFF6C3483),
    },
    {
      'label': 'Romance',
      'sub': 'Love Songs',
      'icon': Icons.favorite_rounded,
      'c1': Color(0xFFE91E8C),
      'c2': Color(0xFFFF6B9D),
    },
    {
      'label': 'Party',
      'sub': 'Turn Up',
      'icon': Icons.celebration_rounded,
      'c1': Color(0xFF667EEA),
      'c2': Color(0xFF764BA2),
    },
    {
      'label': 'Devotional',
      'sub': 'Spiritual',
      'icon': Icons.self_improvement_rounded,
      'c1': Color(0xFFF7971E),
      'c2': Color(0xFFFFD200),
    },
    {
      'label': 'Indie',
      'sub': 'Alternative',
      'icon': Icons.music_note_rounded,
      'c1': Color(0xFF11998E),
      'c2': Color(0xFF38EF7D),
    },
    {
      'label': 'Hip Hop',
      'sub': 'Urban',
      'icon': Icons.mic_rounded,
      'c1': Color(0xFF1A1A2E),
      'c2': Color(0xFF16213E),
    },
    {
      'label': 'Classical',
      'sub': 'Timeless',
      'icon': Icons.piano_rounded,
      'c1': Color(0xFFC9A96E),
      'c2': Color(0xFF8B6914),
    },
    {
      'label': 'Chill',
      'sub': 'Lo-fi Vibes',
      'icon': Icons.waves_rounded,
      'c1': Color(0xFF2193B0),
      'c2': Color(0xFF6DD5FA),
    },
    {
      'label': 'Workout',
      'sub': 'High Energy',
      'icon': Icons.fitness_center_rounded,
      'c1': Color(0xFFFF416C),
      'c2': Color(0xFFFF4B2B),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Browse',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'all genres',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
            ),
            itemCount: _cats.length,
            itemBuilder: (_, i) {
              final cat = _cats[i];
              final c1 = cat['c1'] as Color;
              final c2 = cat['c2'] as Color;
              final icon = cat['icon'] as IconData;
              return _GenreCard(
                label: cat['label'] as String,
                sub: cat['sub'] as String,
                icon: icon,
                c1: c1,
                c2: c2,
                delay: i * 40,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap('${cat['label']} hindi songs');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenreCard extends StatefulWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color c1;
  final Color c2;
  final int delay;
  final VoidCallback onTap;

  const _GenreCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.c1,
    required this.c2,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.c1, widget.c2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Large bg icon
                Positioned(
                  right: -12,
                  bottom: -16,
                  child: Icon(
                    widget.icon,
                    size: 68,
                    color: Colors.black.withOpacity(0.15),
                  ),
                ),
                // Noise overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon,
                            color: Colors.white, size: 16),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.sub,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: widget.delay), duration: 350.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          delay: Duration(milliseconds: widget.delay),
          duration: 350.ms,
          curve: Curves.easeOutBack,
        );
  }
}

// ─── PREMIUM RESULTS BODY ─────────────────────────────────────

class _PremiumResultsBody extends ConsumerWidget {
  final AsyncValue<List<Song>> results;
  final String filter;
  final String query;
  final ScrollController scrollController;

  const _PremiumResultsBody({
    required this.results,
    required this.filter,
    required this.query,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return results.when(
      loading: () => _buildShimmer(),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: Colors.red))),
      data: (songs) {
        if (songs.isEmpty) return _PremiumNoResults(query: query);
        final display = songs;
        return CustomScrollView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Result count pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        '${display.length} results',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'for "$query"',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // Top Result
            if (display.isNotEmpty)
              SliverToBoxAdapter(
                child: _PremiumTopResult(
                  song: display.first,
                  onTap: () => playQueue(ref, display, 0,
                      meta: const QueueMeta(
                          context: QueueContext.general)),
                ).animate().fadeIn(duration: 400.ms).slideY(
                      begin: 0.06,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),

            // Section header for rest
            if (display.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Songs',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 300.ms),
              ),

            // Song list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final song = display[i + 1];
                  return _PremiumResultTile(
                    song: song,
                    index: i + 1,
                    onTap: () => playQueue(ref, display, i + 1,
                        meta: const QueueMeta(
                            context: QueueContext.general)),
                    onMore: () =>
                        _showOptions(ctx, ref, song, display, i + 1),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: i * 25),
                        duration: 280.ms,
                      ).slideX(
                        begin: 0.03,
                        end: 0,
                        delay: Duration(milliseconds: i * 25),
                        duration: 280.ms,
                        curve: Curves.easeOutCubic,
                      );
                },
                childCount:
                    display.length > 1 ? display.length - 1 : 0,
              ),
            ),

            const SliverToBoxAdapter(
                child: SizedBox(height: 160)),
          ],
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        height: 68,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1400.ms,
            color: Colors.white.withOpacity(0.045),
          ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, Song song,
      List<Song> playlist, int index) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PremiumSongOptionsSheet(
          song: song, ref: ref, playlist: playlist, index: index),
    );
  }
}

// ─── PREMIUM TOP RESULT ───────────────────────────────────────

class _PremiumTopResult extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;
  const _PremiumTopResult({required this.song, required this.onTap});

  @override
  State<_PremiumTopResult> createState() => _PremiumTopResultState();
}

class _PremiumTopResultState extends State<_PremiumTopResult> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 5),
              const Text(
                'Top Result',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ]),
          ),
          GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.975 : 1.0,
              duration: const Duration(milliseconds: 130),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.white.withOpacity(0.09),
                        Colors.white.withOpacity(0.04),
                      ]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Row(
                      children: [
                        // Large album art
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            bottomLeft: Radius.circular(22),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: widget.song.image,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 110,
                              height: 110,
                              color: AppTheme.bgTertiary,
                              child: const Icon(Icons.music_note,
                                  color: AppTheme.pink, size: 36),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.pink
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: Border.all(
                                        color: AppTheme.pink
                                            .withOpacity(0.25)),
                                  ),
                                  child: Text(
                                    'SONG',
                                    style: TextStyle(
                                      color: AppTheme.pink
                                          .withOpacity(0.9),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.song.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.song.artist,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withOpacity(0.45),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(children: [
                                  // Play button
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient:
                                          AppTheme.primaryGradient,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.pink
                                              .withOpacity(0.4),
                                          blurRadius: 14,
                                          spreadRadius: -3,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PREMIUM RESULT TILE ─────────────────────────────────────

class _PremiumResultTile extends StatefulWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _PremiumResultTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onMore,
  });

  @override
  State<_PremiumResultTile> createState() => _PremiumResultTileState();
}

class _PremiumResultTileState extends State<_PremiumResultTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Thumbnail with play overlay on press
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.song.image,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 54,
                      height: 54,
                      color: AppTheme.bgTertiary,
                      child: const Icon(Icons.music_note,
                          color: AppTheme.pink, size: 22),
                    ),
                  ),
                ),
                if (_pressed)
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.song.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Duration
            Text(
              _fmt(int.tryParse(widget.song.duration) ?? 0),
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            // More button
            GestureDetector(
              onTap: widget.onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int s) {
    if (s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

// ─── PREMIUM NO RESULTS ───────────────────────────────────────

class _PremiumNoResults extends StatelessWidget {
  final String query;
  const _PremiumNoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"$query"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Try different keywords\nor check the spelling',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .scale(
            begin: const Offset(0.92, 0.92),
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }
}

// ─── PREMIUM SONG OPTIONS SHEET ───────────────────────────────

class _PremiumSongOptionsSheet extends StatelessWidget {
  final Song song;
  final WidgetRef ref;
  final List<Song> playlist;
  final int index;

  const _PremiumSongOptionsSheet({
    required this.song,
    required this.ref,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.82),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Song info row
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: song.image,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 54,
                      height: 54,
                      color: AppTheme.bgTertiary,
                      child: const Icon(Icons.music_note,
                          color: AppTheme.pink),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 18),
              Divider(color: Colors.white.withOpacity(0.07)),
              const SizedBox(height: 8),

              // Options
              ...[
                (Icons.favorite_rounded, 'Like Song', AppTheme.pink),
                (Icons.playlist_add_rounded, 'Add to Playlist',
                    AppTheme.purple),
                (Icons.queue_music_rounded, 'Play Next',
                    AppTheme.pinkDeep),
                (Icons.person_rounded, 'Go to Artist',
                    Colors.white54),
                (Icons.share_rounded, 'Share', Colors.white54),
              ].map(
                (o) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (o.$3 as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(o.$1 as IconData,
                        color: o.$3 as Color, size: 18),
                  ),
                  title: Text(
                    o.$2 as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    if (o.$2 == 'Like Song') {
                      await ref
                          .read(databaseServiceProvider)
                          .likeSong(song);
                    } else if (o.$2 == 'Play Next') {
                      final pl = ref.read(currentPlaylistProvider);
                      final idx = ref.read(currentSongIndexProvider);
                      final nl = [...pl]..insert(idx + 1, song);
                      ref
                          .read(currentPlaylistProvider.notifier)
                          .state = nl;
                    }
                    if (context.mounted) Navigator.pop(context);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}