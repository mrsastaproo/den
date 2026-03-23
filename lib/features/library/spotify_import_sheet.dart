import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/spotify_import_service.dart';
import '../../core/theme/app_theme.dart';

class SpotifyImportSheet extends ConsumerStatefulWidget {
  const SpotifyImportSheet({super.key});

  @override
  ConsumerState<SpotifyImportSheet> createState() => _SpotifyImportSheetState();
}

class _SpotifyImportSheetState extends ConsumerState<SpotifyImportSheet> {
  final _urlCtrl = TextEditingController();
  final List<ImportLogEntry> _logs = [];
  bool _isImporting = false;
  bool _isDone = false;
  final ScrollController _scrollCtrl = ScrollController();

  Future<void> _startImport() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isImporting = true;
      _isDone = false;
      _logs.clear();
    });

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final service = ref.read(spotifyImportServiceProvider);

    await for (final log in service.importPlaylist(url)) {
      if (!mounted) return;
      
      setState(() {
        _logs.add(log);
        if (log.type == ImportLogType.done || log.type == ImportLogType.error) {
          _isImporting = false;
          _isDone = true;
        }
      });

      // Auto-scroll to bottom of logs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
      if (_isDone) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Color(0xFF1DB954), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text('Import via Spotify',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),

              // Input field (hidden if finished)
              if (!_isDone)
                TextField(
                  controller: _urlCtrl,
                  enabled: !_isImporting,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://open.spotify.com/playlist/...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1DB954))),
                  ),
                ),

              const SizedBox(height: 16),

              // Dynamic Log Terminal Screen (Expands up to 300 height)
              if (_logs.isNotEmpty || _isImporting)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 220,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final log = _logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  color: log.type == ImportLogType.error
                                      ? Colors.redAccent
                                      : log.type == ImportLogType.success || log.type == ImportLogType.done
                                          ? Colors.greenAccent
                                          : Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                  fontFamily: 'monospace', // Gives a terminal vibe
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (_logs.isNotEmpty || _isImporting) const SizedBox(height: 20),

              // Import Action Button
              GestureDetector(
                onTap: _isImporting ? null : (_isDone ? () => Navigator.pop(context) : _startImport),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isImporting 
                        ? Colors.white.withOpacity(0.1) 
                        : (_isDone ? Colors.white.withOpacity(0.1) : const Color(0xFF1DB954)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _isImporting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isDone ? 'Close Window' : 'Scan & Import',
                            style: TextStyle(
                              color: _isDone || _isImporting ? Colors.white : Colors.black, 
                              fontSize: 16, 
                              fontWeight: FontWeight.w800
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
