import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/local/app_storage.dart';

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

  String get releaseKey => '$latestVersion+$latestBuild';
}

class AppUpdateService {
  AppUpdateService({AppStorage? storage}) : _storage = storage ?? AppStorage();

  static const _preferredManifestUrlKey = 'preferred_update_manifest_url';
  static const _preferredDownloadProxyKey = 'preferred_update_download_proxy';
  static const _ignoredReleaseKey = 'ignored_update_release_key';
  static const _manifestRequestTimeout = Duration(seconds: 4);
  static const _downloadProbeTimeout = Duration(seconds: 2);
  static const _defaultManifestUrls = [
    'https://cdn.jsdelivr.net/gh/Biscuits47/PocketMeow@main/update/latest.json',
    'https://fastly.jsdelivr.net/gh/Biscuits47/PocketMeow@main/update/latest.json',
    'https://raw.githubusercontent.com/Biscuits47/PocketMeow/main/update/latest.json',
    'https://api.github.com/repos/Biscuits47/PocketMeow/releases/latest',
  ];
  static const _downloadProxyEntries = [
    _DownloadProxyEntry(id: 'direct', urlPrefix: ''),
    _DownloadProxyEntry(
      id: 'mirror.ghproxy',
      urlPrefix: 'https://mirror.ghproxy.com/',
    ),
    _DownloadProxyEntry(
      id: 'ghproxy.net',
      urlPrefix: 'https://ghproxy.net/',
    ),
    _DownloadProxyEntry(
      id: 'kkgithub',
      urlPrefix: 'https://kkgithub.com/',
      replaceGithubHost: true,
    ),
    _DownloadProxyEntry(
      id: 'gh-proxy',
      urlPrefix: 'https://gh-proxy.com/',
    ),
  ];

  final AppStorage _storage;

  Future<AppUpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _normalizeVersion(packageInfo.version);
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final manifestUrls = await _manifestUrls;
    final attempts = await Future.wait(
      manifestUrls.map(
        (manifestUrl) => _loadManifestCandidate(
          manifestUrl: manifestUrl,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
        ),
      ),
    );

    final successAttempts =
        attempts.where((attempt) => attempt.info != null).toList()
          ..sort((left, right) {
            final latencyCompare = left.elapsed.compareTo(right.elapsed);
            if (latencyCompare != 0) {
              return latencyCompare;
            }
            return left.manifestUrl.compareTo(right.manifestUrl);
          });

    if (successAttempts.isNotEmpty) {
      final selected = successAttempts.first;
      await _storage.writePreference(
        _preferredManifestUrlKey,
        selected.manifestUrl,
      );
      return selected.info!;
    }

    final errors = attempts
        .map((attempt) => attempt.error)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final lastError = errors.isEmpty ? null : errors.join('；');
    throw Exception(
      '无法获取版本清单，请检查国内托管地址是否可访问。${lastError == null ? '' : ' 最后一次错误: $lastError'}',
    );
  }

  Future<bool> isIgnoredRelease(AppUpdateInfo info) async {
    final ignoredReleaseKey = await _storage.readPreference(_ignoredReleaseKey);
    return ignoredReleaseKey == info.releaseKey;
  }

  Future<void> ignoreRelease(AppUpdateInfo info) {
    return _storage.writePreference(_ignoredReleaseKey, info.releaseKey);
  }

  Future<void> clearIgnoredRelease() {
    return _storage.deletePreference(_ignoredReleaseKey);
  }

  Future<List<String>> get _manifestUrls async {
    const raw = String.fromEnvironment('POCKETMEOW_UPDATE_MANIFEST_URLS');
    final manifestUrls = raw.trim().isEmpty
        ? _defaultManifestUrls
        : raw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
    final preferredManifestUrl =
        await _storage.readPreference(_preferredManifestUrlKey);
    return _prioritizeList(manifestUrls, preferredManifestUrl);
  }

  Future<_ManifestLoadAttempt> _loadManifestCandidate({
    required String manifestUrl,
    required String currentVersion,
    required int currentBuild,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(
        Uri.parse(manifestUrl),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'PocketMeow-App',
        },
      ).timeout(_manifestRequestTimeout);

      if (response.statusCode != 200) {
        return _ManifestLoadAttempt(
          manifestUrl: manifestUrl,
          elapsed: stopwatch.elapsed,
          error: '[$manifestUrl] 版本清单不可用: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = _normalizeVersion(
        (json['tag_name'] as String?) ??
            (json['version'] as String?) ??
            (json['latest_version'] as String?) ??
            currentVersion,
      );
      final latestBuild = _parseBuildNumber(json['build']) ??
          _parseBuildNumber(json['latest_build']) ??
          currentBuild;
      final detailsUrl = _readString(
              json, ['html_url', 'page_url', 'details_url', 'details']) ??
          manifestUrl;

      String? downloadUrl = _extractDownloadUrl(json);
      if (downloadUrl != null && _isGithubReleaseUrl(downloadUrl)) {
        downloadUrl = await _getFastestDownloadUrl(downloadUrl);
      }

      final releaseNotes = _readString(
              json, ['body', 'notes', 'release_notes', 'description']) ??
          '';
      final publishedAt = DateTime.tryParse(
        _readString(json, ['published_at', 'updated_at']) ?? '',
      );

      return _ManifestLoadAttempt(
        manifestUrl: manifestUrl,
        elapsed: stopwatch.elapsed,
        info: AppUpdateInfo(
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
        ),
      );
    } catch (error) {
      return _ManifestLoadAttempt(
        manifestUrl: manifestUrl,
        elapsed: stopwatch.elapsed,
        error: '[$manifestUrl] $error',
      );
    } finally {
      stopwatch.stop();
    }
  }

  List<String> _prioritizeList(List<String> values, String? preferredValue) {
    if (preferredValue == null || preferredValue.trim().isEmpty) {
      return values;
    }
    final preferred = preferredValue.trim();
    final unique = <String>{};
    final ordered = <String>[];
    for (final item in [preferred, ...values]) {
      if (item.trim().isEmpty || !unique.add(item)) {
        continue;
      }
      ordered.add(item);
    }
    return ordered;
  }

  String? _extractDownloadUrl(Map<String, dynamic> json) {
    String? downloadUrl;
    if (json['assets'] is List) {
      final assets = json['assets'] as List;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final url = asset['browser_download_url'] as String?;
          if (url != null && url.endsWith('.apk')) {
            downloadUrl = url;
            break;
          }
        }
      }
    }
    return downloadUrl ?? _readString(json, ['apk_url', 'download_url']);
  }

  bool _isGithubReleaseUrl(String url) {
    return url.startsWith('https://github.com/');
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

  Future<String> _getFastestDownloadUrl(String originalUrl) async {
    if (!_isGithubReleaseUrl(originalUrl)) {
      return originalUrl;
    }

    final preferredProxyId =
        await _storage.readPreference(_preferredDownloadProxyKey);
    final orderedEntries = _orderedDownloadProxyEntries(preferredProxyId);
    final attempts = await Future.wait(
      orderedEntries.map(
        (entry) => _probeDownloadUrl(entry: entry, originalUrl: originalUrl),
      ),
    );
    final validAttempts =
        attempts.where((attempt) => attempt.resolvedUrl != null).toList()
          ..sort((left, right) {
            final latencyCompare = left.elapsed.compareTo(right.elapsed);
            if (latencyCompare != 0) {
              return latencyCompare;
            }
            final leftDirectPriority = left.proxy.id == 'direct' ? 0 : 1;
            final rightDirectPriority = right.proxy.id == 'direct' ? 0 : 1;
            return leftDirectPriority.compareTo(rightDirectPriority);
          });

    if (validAttempts.isNotEmpty) {
      final fastest = validAttempts.first;
      await _storage.writePreference(
        _preferredDownloadProxyKey,
        fastest.proxy.id,
      );
      return fastest.resolvedUrl!;
    }

    return originalUrl;
  }

  List<_DownloadProxyEntry> _orderedDownloadProxyEntries(String? preferredId) {
    if (preferredId == null || preferredId.trim().isEmpty) {
      return _downloadProxyEntries;
    }
    final ordered = <_DownloadProxyEntry>[];
    final usedIds = <String>{};
    for (final entry in _downloadProxyEntries) {
      if (entry.id == preferredId && usedIds.add(entry.id)) {
        ordered.add(entry);
      }
    }
    for (final entry in _downloadProxyEntries) {
      if (usedIds.add(entry.id)) {
        ordered.add(entry);
      }
    }
    return ordered;
  }

  Future<_DownloadProbeResult> _probeDownloadUrl({
    required _DownloadProxyEntry entry,
    required String originalUrl,
  }) async {
    final resolvedUrl = entry.resolve(originalUrl);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.head(
        Uri.parse(resolvedUrl),
        headers: const {'User-Agent': 'PocketMeow-App'},
      ).timeout(_downloadProbeTimeout);
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return _DownloadProbeResult(
          proxy: entry,
          elapsed: stopwatch.elapsed,
          resolvedUrl: resolvedUrl,
        );
      }
      return _DownloadProbeResult(proxy: entry, elapsed: stopwatch.elapsed);
    } catch (_) {
      return _DownloadProbeResult(proxy: entry, elapsed: stopwatch.elapsed);
    } finally {
      stopwatch.stop();
    }
  }
}

class _ManifestLoadAttempt {
  const _ManifestLoadAttempt({
    required this.manifestUrl,
    required this.elapsed,
    this.info,
    this.error,
  });

  final String manifestUrl;
  final Duration elapsed;
  final AppUpdateInfo? info;
  final String? error;
}

class _DownloadProxyEntry {
  const _DownloadProxyEntry({
    required this.id,
    required this.urlPrefix,
    this.replaceGithubHost = false,
  });

  final String id;
  final String urlPrefix;
  final bool replaceGithubHost;

  String resolve(String originalUrl) {
    if (replaceGithubHost) {
      return originalUrl.replaceFirst('https://github.com/', urlPrefix);
    }
    return urlPrefix.isEmpty ? originalUrl : '$urlPrefix$originalUrl';
  }
}

class _DownloadProbeResult {
  const _DownloadProbeResult({
    required this.proxy,
    required this.elapsed,
    this.resolvedUrl,
  });

  final _DownloadProxyEntry proxy;
  final Duration elapsed;
  final String? resolvedUrl;
}
