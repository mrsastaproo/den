import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';
import '../../shared/widgets/update_dialog.dart';

/// Result of an update check.
enum UpdateStatus { upToDate, optionalUpdate, forceUpdate, error }

class UpdateCheckResult {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final String? errorMessage;

  const UpdateCheckResult._({
    required this.status,
    this.updateInfo,
    this.errorMessage,
  });

  factory UpdateCheckResult.upToDate() =>
      const UpdateCheckResult._(status: UpdateStatus.upToDate);

  factory UpdateCheckResult.optional(UpdateInfo info) =>
      UpdateCheckResult._(status: UpdateStatus.optionalUpdate, updateInfo: info);

  factory UpdateCheckResult.force(UpdateInfo info) =>
      UpdateCheckResult._(status: UpdateStatus.forceUpdate, updateInfo: info);

  factory UpdateCheckResult.error(String message) =>
      UpdateCheckResult._(status: UpdateStatus.error, errorMessage: message);
}

class UpdateService {
  /// URL to your hosted update.json
  static const String _updateJsonUrl =
      'https://denmusic.in/update.json'; // ← change this

  static const Duration _timeout = Duration(seconds: 10);

  /// Checks for updates and shows the dialog if needed.
  static Future<void> checkUpdate(BuildContext context) async {
    final result = await checkForUpdate();
    if (result.status == UpdateStatus.optionalUpdate ||
        result.status == UpdateStatus.forceUpdate) {
      if (!context.mounted) return;
      
      final info = result.updateInfo!;
      showDialog(
        context: context,
        barrierDismissible: result.status != UpdateStatus.forceUpdate,
        builder: (ctx) => UpdateDialog(
          title: info.title,
          message: info.message,
          updateUrl: info.updateUrl,
          isForceUpdate: result.status == UpdateStatus.forceUpdate,
        ),
      );
    }
  }

  /// Fetches the remote JSON and compares against the current app version.
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      final response = await http
          .get(Uri.parse(_updateJsonUrl))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return UpdateCheckResult.error(
            'Server returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(json);

      final current = _parseVersion(currentVersion);
      final latest = _parseVersion(info.latestVersion);
      final minSupported = _parseVersion(info.minSupportedVersion);

      // No update needed
      if (!_isLower(current, latest)) {
        return UpdateCheckResult.upToDate();
      }

      // Force update: current version is below minimum OR update_type is force
      if (_isLowerOrEqual(current, minSupported) || info.isForceUpdate) {
        return UpdateCheckResult.force(info);
      }

      // Optional update
      return UpdateCheckResult.optional(info);
    } catch (e) {
      // Silently fail — never block the user due to a network error
      return UpdateCheckResult.error(e.toString());
    }
  }

  /// Converts "1.2.3" → [1, 2, 3]
  static List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }

  /// Returns true if [a] is strictly lower than [b]
  static bool _isLower(List<int> a, List<int> b) {
    for (int i = 0; i < 3; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return true;
      if (av > bv) return false;
    }
    return false;
  }

  /// Returns true if [a] is lower than or equal to [b]
  static bool _isLowerOrEqual(List<int> a, List<int> b) {
    return !_isLower(b, a); // b is NOT lower than a → a <= b
  }
}