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
import '../../shared/widgets/social_share_sheet.dart';
import '../../core/services/download_service.dart';
import '../../core/services/audius_service.dart';

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
        [q.trim(), ...state.where((s) => s != q.trim())].take(10).toList();
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
  double _scrollOffset = 0;
  late AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    _scrollController
        .addListener(() => setState(() => _scrollOffset = _scrollController.offset));
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scrollController.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    _ctrl.text = q;
    // Bump seed BEFORE setting query so provider re-fetches with new shuffle
    ref.read(searchShuffleSeedProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch;
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _SearchAmbient(ctrl: _orbCtrl),
            Column(
              children: [
                _SearchHeader(
                  ctrl: _ctrl,
                  focus: _focus,
                  focused: _focused,
                  scrolled: _scrollOffset > 8,
                  query: query,
                  onChanged: (q) =>
                      ref.read(searchQueryProvider.notifier).state = q,
                  onSubmit: (q) {
                    _search(q);
                    FocusScope.of(context).unfocus();
                  },
                  onClear: _clear,
                  onCancel: () {
                    FocusScope.of(context).unfocus();
                    if (query.isEmpty) _clear();
                  },
                ),
                if (query.isNotEmpty)
                  _FilterRow(
                    selected: filter,
                    onSelect: (f) {
                      HapticFeedback.selectionClick();
                      ref.read(searchFilterProvider.notifier).state = f;
                    },
                  ),
                Expanded(
                  child: query.isEmpty
                      ? _BrowseBody(
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
                          onCategoryTap: (q) {
                            _search(q);
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : _ResultsBody(
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
      ),
    );
  }
}

// ─── AMBIENT ──────────────────────────────────────────────────

class _SearchAmbient extends StatelessWidget {
  final AnimationController ctrl;
  const _SearchAmbient({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        return Stack(children: [
          Positioned(
            top: -110 + math.sin(t * math.pi) * 28,
            left: -70 + math.cos(t * math.pi * 0.7) * 18,
            child: _Orb(320, AppTheme.pink, 0.10 + t * 0.04),
          ),
          Positioned(
            top: 90 + math.cos(t * math.pi * 1.2) * 18,
            right: -55,
            child: _Orb(230, AppTheme.purple, 0.08 + t * 0.03),
          ),
          Positioned(
            bottom: 220,
            left: 30 + math.sin(t * math.pi * 1.6) * 14,
            child: _Orb(170, AppTheme.pinkDeep, 0.055 + t * 0.02),
          ),
        ]);
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Orb(this.size, this.color, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color.withOpacity(opacity), Colors.transparent]),
      ),
    );
  }
}

// ─── SEARCH HEADER ────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool focused;
  final bool scrolled;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  const _SearchHeader({
    required this.ctrl,
    required this.focus,
    required this.focused,
    required this.scrolled,
    required this.query,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: EdgeInsets.fromLTRB(20, top + 10, 20, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(scrolled ? 0.70 : 0.48),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(scrolled ? 0.07 : 0.0),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: focused
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(children: [
                          _WaveIcon(),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.2,
                                  height: 1.0,
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (b) =>
                                    AppTheme.primaryGradient.createShader(b),
                                child: const Text(
                                  'artists, songs & vibes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ])
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(
                              begin: -0.1,
                              end: 0,
                              duration: 300.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ),
              ),
              // Search bar row
              Row(
                children: [
                  Expanded(
                    child: _SearchBarWidget(
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
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: focused
                        ? Row(children: [
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: onCancel,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 0.8),
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
                                  curve: Curves.easeOutCubic,
                                ),
                          ])
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

// ─── WAVE ICON ────────────────────────────────────────────────

class _WaveIcon extends StatefulWidget {
  @override
  State<_WaveIcon> createState() => _WaveIconState();
}

class _WaveIconState extends State<_WaveIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 860))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppTheme.pink.withOpacity(0.38),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        child: CustomPaint(painter: _BarsPainter(_c.value)),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final double t;
  _BarsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    const n = 5;
    const bw = 2.4;
    final gap = (size.width - n * bw) / (n + 1);
    const hs = [0.28, 0.62, 1.0, 0.62, 0.28];
    for (int i = 0; i < n; i++) {
      final phase = (t - i * 0.14) % 1.0;
      final wave = math.sin(phase * math.pi * 2);
      final h = hs[i] * (0.38 + 0.62 * ((wave + 1) / 2)) * size.height * 0.62;
      final x = gap + i * (bw + gap) + bw / 2;
      final cy = size.height / 2;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.t != t;
}

// ─── SEARCH BAR WIDGET ────────────────────────────────────────

class _SearchBarWidget extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool focused;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  const _SearchBarWidget({
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
              ? AppTheme.pink.withOpacity(0.55)
              : Colors.white.withOpacity(0.09),
          width: focused ? 1.5 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                    color: AppTheme.pink.withOpacity(0.18),
                    blurRadius: 28,
                    spreadRadius: -6),
                BoxShadow(
                    color: AppTheme.purple.withOpacity(0.12),
                    blurRadius: 36,
                    spreadRadius: -10),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Colors.white.withOpacity(focused ? 0.10 : 0.06),
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              onChanged: onChanged,
              onSubmitted: onSubmit,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
              cursorColor: AppTheme.pink,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                hintText: 'Songs, artists, albums, moods…',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.28),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(13),
                  child: ShaderMask(
                    shaderCallback: (b) => (focused
                            ? AppTheme.primaryGradient
                            : LinearGradient(colors: [
                                Colors.white.withOpacity(0.32),
                                Colors.white.withOpacity(0.32),
                              ]))
                        .createShader(b),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 21),
                  ),
                ),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(
                        onTap: onClear,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 13),
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── FILTER ROW ───────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterRow({required this.selected, required this.onSelect});

  static const _filters = ['All', 'Songs', 'Artists', 'Albums'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
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
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: sel ? AppTheme.primaryGradient : null,
                  color: sel ? null : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: sel
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.10),
                    width: 0.8,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: AppTheme.pink.withOpacity(0.32),
                              blurRadius: 14,
                              spreadRadius: -4)
                        ]
                      : [],
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color:
                        sel ? Colors.white : Colors.white.withOpacity(0.50),
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: sel ? 0.2 : 0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 220.ms);
  }
}

// ─── BROWSE BODY ──────────────────────────────────────────────

class _BrowseBody extends StatefulWidget {
  final List<String> recents;
  final ScrollController scrollController;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final VoidCallback onClearAll;
  final ValueChanged<String> onCategoryTap;

  const _BrowseBody({
    required this.recents,
    required this.scrollController,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onClearAll,
    required this.onCategoryTap,
  });

  @override
  State<_BrowseBody> createState() => _BrowseBodyState();
}

class _BrowseBodyState extends State<_BrowseBody> {
  static const _collapsedMax = 5;
  bool _expanded = false;

  @override
  void didUpdateWidget(_BrowseBody old) {
    super.didUpdateWidget(old);
    // Auto-collapse if recents drop to 5 or fewer
    if (widget.recents.length <= _collapsedMax && _expanded) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recents = widget.recents;
    final hasMore = recents.length > _collapsedMax;
    final hidden = recents.length - _collapsedMax;
    final visible = _expanded
        ? recents
        : recents.take(_collapsedMax).toList();

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Recent Searches ───────────────────────────────
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ]),
                GestureDetector(
                  onTap: widget.onClearAll,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: AppTheme.pink.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Visible tiles (max 5 when collapsed)
          ...visible.asMap().entries.map(
            (e) => _RecentTile(
              query: e.value,
              onTap: () => widget.onRecentTap(e.value),
              onRemove: () => widget.onRecentRemove(e.value),
            )
                .animate()
                .fadeIn(
                    delay: Duration(milliseconds: e.key * 35),
                    duration: 280.ms)
                .slideX(
                  begin: -0.04,
                  end: 0,
                  delay: Duration(milliseconds: e.key * 35),
                  duration: 280.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),

          // ── See more / Show less button ─────────────────
          if (hasMore)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.pink.withOpacity(0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: Text(
                        _expanded
                            ? 'Show less'
                            : 'See $hidden more',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 220.ms),

          const SizedBox(height: 10),
          Divider(
              color: Colors.white.withOpacity(0.05),
              indent: 20,
              endIndent: 20),
        ],

        // ── Browse categories ─────────────────────────────
        _BrowseGrid(onTap: widget.onCategoryTap),

        const SizedBox(height: 180),
      ],
    );
  }
}

// ─── RECENT TILE ──────────────────────────────────────────────

class _RecentTile extends StatefulWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentTile(
      {required this.query, required this.onTap, required this.onRemove});

  @override
  State<_RecentTile> createState() => _RecentTileState();
}

class _RecentTileState extends State<_RecentTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.09)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(_pressed ? 0.12 : 0.05),
            width: 0.8,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withOpacity(0.08), width: 0.5),
            ),
            child: Icon(Icons.history_rounded,
                color: Colors.white.withOpacity(0.35), size: 16),
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
              child: Icon(Icons.north_west_rounded,
                  color: Colors.white.withOpacity(0.22), size: 14),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── BROWSE GRID ──────────────────────────────────────────────

class _BrowseGrid extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _BrowseGrid({required this.onTap});

  // Real Unsplash images — each matched to the genre's mood
  static const _cats = [
    _Cat(
      label: 'Bollywood',
      sub: 'Hindi Films',
      query: 'bollywood hindi songs 2025',
      image: 'https://images.unsplash.com/photo-1626379953822-baec19c3accd?w=600&q=80',
      c1: Color(0xFFFF6B6B),
      c2: Color(0xFFFF8E53),
    ),
    _Cat(
      label: 'Punjabi',
      sub: 'Desi Beats',
      query: 'punjabi hits 2025',
      image: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      c1: Color(0xFF9B59B6),
      c2: Color(0xFF6C3483),
    ),
    _Cat(
      label: 'Romance',
      sub: 'Love Songs',
      query: 'romantic love songs hindi',
      image: 'https://images.unsplash.com/photo-1518621736915-f3b1c41bfd00?w=600&q=80',
      c1: Color(0xFFE91E8C),
      c2: Color(0xFFFF6B9D),
    ),
    _Cat(
      label: 'Party',
      sub: 'Turn It Up',
      query: 'party dance hindi songs',
      image: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=600&q=80',
      c1: Color(0xFF667EEA),
      c2: Color(0xFF764BA2),
    ),
    _Cat(
      label: 'Devotional',
      sub: 'Spiritual',
      query: 'best bhajan devotional hindi',
      image: 'https://images.unsplash.com/photo-1602526429747-ac387a91d43b?w=600&q=80',
      c1: Color(0xFFF7971E),
      c2: Color(0xFFFFD200),
    ),
    _Cat(
      label: 'Indie',
      sub: 'Underground Gems',
      query: 'indie hindi independent artists',
      image: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      c1: Color(0xFF11998E),
      c2: Color(0xFF38EF7D),
    ),
    _Cat(
      label: 'Hip Hop',
      sub: 'Urban Vibes',
      query: 'hindi hip hop rap songs',
      image: 'https://images.unsplash.com/photo-1571609803939-54d71e14cae5?w=600&q=80',
      c1: Color(0xFF1A1A2E),
      c2: Color(0xFF16213E),
    ),
    _Cat(
      label: 'Classical',
      sub: 'Timeless',
      query: 'indian classical music ragas',
      image: 'https://images.unsplash.com/photo-1520523839897-bd0b52f945a0?w=600&q=80',
      c1: Color(0xFFC9A96E),
      c2: Color(0xFF8B6914),
    ),
    _Cat(
      label: 'Chill',
      sub: 'Lo-fi Vibes',
      query: 'chill lofi hindi songs',
      image: 'https://images.unsplash.com/photo-1516912481808-3406841bd33c?w=600&q=80',
      c1: Color(0xFF2193B0),
      c2: Color(0xFF6DD5FA),
    ),
    _Cat(
      label: 'Workout',
      sub: 'Beast Mode',
      query: 'workout gym motivation hindi songs',
      image: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
      c1: Color(0xFFFF416C),
      c2: Color(0xFFFF4B2B),
    ),
    _Cat(
      label: 'Sad Songs',
      sub: 'Feel It All',
      query: 'sad heartbreak hindi songs',
      image: 'https://images.unsplash.com/photo-1498931299472-f7a63a5a1cfa?w=600&q=80',
      c1: Color(0xFF373B44),
      c2: Color(0xFF4286f4),
    ),
    _Cat(
      label: 'Throwback',
      sub: '90s & 2000s',
      query: 'hindi classic 90s 2000s bollywood',
      image: 'https://images.unsplash.com/photo-1471478331149-c72f17e33c73?w=600&q=80',
      c1: Color(0xFFFFC371),
      c2: Color(0xFFFF5F6D),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Row(children: [
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'all genres',
              style: TextStyle(
                color: Colors.white.withOpacity(0.32),
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
              ),
            ),
          ]),
        ),
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
            itemCount: _cats.length,
            itemBuilder: (_, i) => _CategoryCard(
              cat: _cats[i],
              delay: i * 45,
              onTap: () => onTap(_cats[i].query),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── CATEGORY MODEL ───────────────────────────────────────────

class _Cat {
  final String label;
  final String sub;
  final String query;
  final String image;
  final Color c1;
  final Color c2;

  const _Cat({
    required this.label,
    required this.sub,
    required this.query,
    required this.image,
    required this.c1,
    required this.c2,
  });
}

// ─── CATEGORY CARD with real background image ─────────────────

class _CategoryCard extends StatefulWidget {
  final _Cat cat;
  final int delay;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.cat, required this.delay, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Real background image ─────────────────────
              CachedNetworkImage(
                imageUrl: widget.cat.image,
                fit: BoxFit.cover,
                // Fallback gradient if image fails to load
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.cat.c1, widget.cat.c2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // ── Cinematic colour-tinted overlay ──────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.cat.c1.withOpacity(0.52),
                      widget.cat.c2.withOpacity(0.38),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // ── Bottom scrim — ensures text always readable
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // ── Text labels ───────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.cat.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.1,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 10)
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.cat.sub,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 6)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Press ripple ──────────────────────────────
              if (_pressed)
                Container(color: Colors.white.withOpacity(0.07)),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: widget.delay),
            duration: 380.ms)
        .scale(
          begin: const Offset(0.88, 0.88),
          delay: Duration(milliseconds: widget.delay),
          duration: 380.ms,
          curve: Curves.easeOutBack,
        );
  }
}

// ─── RESULTS BODY ─────────────────────────────────────────────

class _ResultsBody extends ConsumerWidget {
  final AsyncValue<List<Song>> results;
  final String filter;
  final String query;
  final ScrollController scrollController;

  const _ResultsBody({
    required this.results,
    required this.filter,
    required this.query,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return results.when(
      loading: _buildShimmer,
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: Colors.red.shade400))),
      data: (songs) {
        if (songs.isEmpty) return _EmptyResults(query: query);

        return CustomScrollView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.09),
                          width: 0.8),
                    ),
                    child: Text(
                      '${songs.length} results',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'for "$query"',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 280.ms),
            ),

            SliverToBoxAdapter(
              child: _TopResultCard(
                song: songs.first,
                onTap: () => playQueue(ref, songs, 0,
                    meta: QueueMeta(
                      context: QueueContext.search,
                      searchQuery: query,
                    )),
              )
                  .animate()
                  .fadeIn(duration: 380.ms)
                  .slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 380.ms,
                      curve: Curves.easeOutCubic),
            ),

            if (songs.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                  child: Row(children: [
                    Container(
                      width: 3,
                      height: 13,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Songs',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 280.ms),
              ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final song = songs[i + 1];
                  return _SongResultTile(
                    song: song,
                    index: i + 1,
                    onTap: () => playQueue(ref, songs, i + 1,
                        meta: QueueMeta(
                          context: QueueContext.search,
                          searchQuery: query,
                        )),
                    onMore: () =>
                        _showOptions(ctx, ref, song, songs, i + 1),
                  )
                      .animate()
                      .fadeIn(
                          delay: Duration(milliseconds: i * 22),
                          duration: 260.ms)
                      .slideX(
                        begin: 0.03,
                        end: 0,
                        delay: Duration(milliseconds: i * 22),
                        duration: 260.ms,
                        curve: Curves.easeOutCubic,
                      );
                },
                childCount: songs.length > 1 ? songs.length - 1 : 0,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, kDenBottomPadding + 40),
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
              duration: 1400.ms,
              color: Colors.white.withOpacity(0.045)),
    );
  }

  void _showOptions(BuildContext ctx, WidgetRef ref, Song song,
      List<Song> playlist, int index) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SongOptionsSheet(
          song: song, ref: ref, playlist: playlist, index: index),
    );
  }
}

// ─── TOP RESULT CARD ──────────────────────────────────────────

class _TopResultCard extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;
  const _TopResultCard({required this.song, required this.onTap});

  @override
  State<_TopResultCard> createState() => _TopResultCardState();
}

class _TopResultCardState extends State<_TopResultCard> {
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
                height: 13,
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
              const SizedBox(width: 6),
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
            behavior: HitTestBehavior.opaque,
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
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.04),
                      ]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 0.8),
                    ),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          bottomLeft: Radius.circular(22),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: widget.song.image,
                          width: 118,
                          height: 118,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 118,
                            height: 118,
                            color: AppTheme.bgTertiary,
                            child: const Icon(Icons.music_note,
                                color: AppTheme.pink, size: 38),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.pink.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppTheme.pink.withOpacity(0.28),
                                      width: 0.7),
                                ),
                                child: Text(
                                  'SONG',
                                  style: TextStyle(
                                    color: AppTheme.pink.withOpacity(0.9),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                widget.song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.song.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.pink.withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
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

// ─── SONG RESULT TILE ─────────────────────────────────────────

class _SongResultTile extends StatefulWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _SongResultTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onMore,
  });

  @override
  State<_SongResultTile> createState() => _SongResultTileState();
}

class _SongResultTileState extends State<_SongResultTile> {
  bool _pressed = false;

  String _fmt(int s) {
    if (s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Stack(alignment: Alignment.center, children: [
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
                  color: Colors.black.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
              ),
          ]),
          const SizedBox(width: 13),
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
                    color: Colors.white.withOpacity(0.40),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _fmt(int.tryParse(widget.song.duration) ?? 0),
            style: TextStyle(
              color: Colors.white.withOpacity(0.24),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: widget.onMore,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Icon(Icons.more_vert_rounded,
                  color: Colors.white.withOpacity(0.28), size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── EMPTY RESULTS ────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

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
                    color: Colors.white.withOpacity(0.08), width: 0.8),
              ),
              child: Icon(Icons.search_off_rounded,
                  color: Colors.white.withOpacity(0.2), size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"$query"',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.30), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Try different keywords\nor check spelling',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.24),
                fontSize: 13,
                height: 1.55,
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
              curve: Curves.easeOutBack),
    );
  }
}

// ─── SONG OPTIONS SHEET ───────────────────────────────────────

class _SongOptionsSheet extends StatelessWidget {
  final Song song;
  final WidgetRef ref;
  final List<Song> playlist;
  final int index;

  const _SongOptionsSheet({
    required this.song,
    required this.ref,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.84),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
                color: Colors.white.withOpacity(0.07), width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
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
                      Text(song.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(song.artist,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Divider(color: Colors.white.withOpacity(0.07), height: 0.5),
              const SizedBox(height: 8),
              ...[
                (Icons.favorite_rounded, 'Like Song', AppTheme.pink),
                (Icons.download_rounded, 'Download', Colors.teal), // [ADD]
                (Icons.playlist_add_rounded, 'Add to Playlist', AppTheme.purple),
                (Icons.queue_music_rounded, 'Play Next', AppTheme.pinkDeep),
                (Icons.person_rounded, 'Go to Artist', Colors.white54),
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
                      border: Border.all(
                          color: (o.$3 as Color).withOpacity(0.2),
                          width: 0.6),
                    ),
                    child: Icon(o.$1 as IconData,
                        color: o.$3 as Color, size: 18),
                  ),
                  title: Text(o.$2 as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  onTap: () async {
                    if (o.$2 == 'Like Song') {
                      await ref.read(databaseServiceProvider).likeSong(song);
                    } else if (o.$2 == 'Download') {
                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Downloading ${song.title}...'), duration: const Duration(seconds: 2))
                      );
                      try {
                        String url = song.url;
                        if (song.id.startsWith('audius_')) {
                          url = await ref.read(audiusServiceProvider).getStreamUrl(song.id);
                        } else if (url.isEmpty) {
                          url = await ref.read(apiServiceProvider).getStreamUrl(song.id);
                        }
                        await ref.read(downloadServiceProvider).downloadSong(song, resolvedUrl: url);
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Downloaded ${song.title} successfully!'))
                           );
                        }
                      } catch (e) {
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to download: $e'), backgroundColor: Colors.red)
                           );
                        }
                      }
                      return;
                    } else if (o.$2 == 'Play Next') {
                      final pl = ref.read(currentPlaylistProvider);
                      final idx = ref.read(currentSongIndexProvider);
                      final nl = [...pl]..insert(idx + 1, song);
                      ref.read(currentPlaylistProvider.notifier).state = nl;
                    } else if (o.$2 == 'Share') {
                      if (context.mounted) Navigator.pop(context);
                      SocialShareSheet.show(context, type: 'song', metadata: song.toJson());
                      return;
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