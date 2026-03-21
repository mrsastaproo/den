import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── QUEUE CONTEXT ────────────────────────────────────────────
// Isolated in its own file to avoid circular imports between
// player_service.dart and music_providers.dart

enum QueueContext {
  general,
  mood,        // e.g. Love, Chill, Hype
  artist,      // Artist Spotlight
  trending,
  topCharts,
  throwback,
  newReleases,
  timeBased,
}

class QueueMeta {
  final QueueContext context;
  final String? mood;
  final String? artistName;
  final String? searchQuery;

  const QueueMeta({
    this.context = QueueContext.general,
    this.mood,
    this.artistName,
    this.searchQuery,
  });
}

final queueMetaProvider = StateProvider<QueueMeta>(
  (ref) => const QueueMeta(),
);