import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String releaseDate;
  final String downloadUrl;
  final String changelog;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.releaseDate,
    required this.downloadUrl,
    required this.changelog,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      build: json['build'] as int,
      releaseDate: json['releaseDate'] as String,
      downloadUrl: json['downloadUrl'] as String,
      changelog: json['changelog'] as String,
    );
  }
}

class UpdateService {
  static const String _releasesUrl =
      'https://raw.githubusercontent.com/ropermen/koder-releases/main/releases.json';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(_releasesUrl));
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final latest = data['latest'] as Map<String, dynamic>;
      final updateInfo = UpdateInfo.fromJson(latest);

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (updateInfo.build > currentBuild) {
        return updateInfo;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> openDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
