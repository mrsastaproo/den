class UpdateInfo {
  final String latestVersion;
  final String minSupportedVersion;
  final String updateType; // "optional" or "force"
  final String title;
  final String message;
  final String updateUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.updateType,
    required this.title,
    required this.message,
    required this.updateUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] as String,
      minSupportedVersion: json['min_supported_version'] as String,
      updateType: json['update_type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      updateUrl: json['app_download_page'] as String,
    );
  }

  bool get isForceUpdate => updateType == 'force';
}