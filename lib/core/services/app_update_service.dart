import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.hasUpdate,
    required this.downloadUrl,
    required this.detailsUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.manifestUrl,
  });

  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final int latestBuild;
  final bool hasUpdate;
  final String? downloadUrl;
  final String detailsUrl;
  final String releaseNotes;
  final DateTime? publishedAt;
  final String manifestUrl;
}

class AppUpdateService {
  static const _defaultManifestUrls = [
    'https://cdn.jsdelivr.net/gh/Biscuits47/PocketMeow@main/update/latest.json',
    'https://fastly.jsdelivr.net/gh/Biscuits47/PocketMeow@main/update/latest.json',
    'https://raw.githubusercontent.com/Biscuits47/PocketMeow/main/update/latest.json',
  ];

  Future<AppUpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _normalizeVersion(packageInfo.version);
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final manifestUrls = _manifestUrls;

    String? lastError;
    for (final manifestUrl in manifestUrls) {
      try {
        final response = await http.get(
          Uri.parse(manifestUrl),
          headers: const {'Accept': 'application/json'},
        );

        if (response.statusCode != 200) {
          lastError = '版本清单不可用: ${response.statusCode}';
          continue;
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final latestVersion = _normalizeVersion(
          (json['version'] as String?) ??
              (json['latest_version'] as String?) ??
              currentVersion,
        );
        final latestBuild = _parseBuildNumber(json['build']) ??
            _parseBuildNumber(json['latest_build']) ??
            currentBuild;
        final detailsUrl =
            _readString(json, ['page_url', 'details_url', 'details']) ??
                manifestUrl;
        final downloadUrl =
            _readString(json, ['apk_url', 'download_url', 'url']);
        final releaseNotes =
            _readString(json, ['notes', 'release_notes', 'description']) ?? '';
        final publishedAt = DateTime.tryParse(
          _readString(json, ['published_at', 'updated_at']) ?? '',
        );

        return AppUpdateInfo(
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          latestVersion: latestVersion,
          latestBuild: latestBuild,
          hasUpdate: _compareRelease(
                latestVersion: latestVersion,
                latestBuild: latestBuild,
                currentVersion: currentVersion,
                currentBuild: currentBuild,
              ) >
              0,
          downloadUrl: downloadUrl,
          detailsUrl: detailsUrl,
          releaseNotes: releaseNotes,
          publishedAt: publishedAt,
          manifestUrl: manifestUrl,
        );
      } catch (error) {
        lastError = error.toString();
      }
    }

    throw Exception(
      '无法获取版本清单，请检查国内托管地址是否可访问。${lastError == null ? '' : ' 最后一次错误: $lastError'}',
    );
  }

  List<String> get _manifestUrls {
    const raw = String.fromEnvironment('POCKETMEOW_UPDATE_MANIFEST_URLS');
    if (raw.trim().isEmpty) {
      return _defaultManifestUrls;
    }

    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int _compareRelease({
    required String latestVersion,
    required int latestBuild,
    required String currentVersion,
    required int currentBuild,
  }) {
    final versionResult = _compareVersions(latestVersion, currentVersion);
    if (versionResult != 0) {
      return versionResult;
    }
    return latestBuild.compareTo(currentBuild);
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  List<int> _versionParts(String version) {
    return _normalizeVersion(version)
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  String _normalizeVersion(String version) {
    final match = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(version);
    return match?.group(1) ?? '0.0.0';
  }

  int? _parseBuildNumber(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
