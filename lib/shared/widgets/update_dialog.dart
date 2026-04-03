import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/update_downloader.dart';

class UpdateDialog extends StatefulWidget {
  final String title;
  final String message;
  final String updateUrl;
  final String latestVersion;
  final bool isForceUpdate;

  const UpdateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.updateUrl,
    required this.latestVersion,
    required this.isForceUpdate,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _startUpdate() async {
    if (_isDownloading) return;

    // Check if the URL is an APK
    if (!widget.updateUrl.toLowerCase().endsWith('.apk')) {
      // Fallback to browser if it's not a direct APK link
      final Uri url = Uri.parse(widget.updateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!widget.isForceUpdate) Navigator.pop(context);
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _error = null;
    });

    await UpdateDownloader.downloadAndInstall(
      url: widget.updateUrl,
      fileName: 'den_update_${widget.latestVersion}.apk',
      onProgress: (p) {
        setState(() => _progress = p);
      },
      onError: (e) {
        setState(() {
          _isDownloading = false;
          _error = e;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForceUpdate && !_isDownloading,
      child: AlertDialog(
        backgroundColor: const Color(0xff121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB3C6)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Downloading ${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFFFFB3C6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            if (widget.isForceUpdate && !_isDownloading) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This update is required to continue using the app.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.isForceUpdate && !_isDownloading)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('dismissed_update_version', widget.latestVersion);
                if (mounted) Navigator.pop(context, false);
              },
              child: Text(
                'Later',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
          if (!_isDownloading)
            ElevatedButton(
              onPressed: _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB3C6),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
