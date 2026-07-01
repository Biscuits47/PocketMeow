import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(
    Uri.parse(
        'https://api.github.com/repos/Biscuits47/PocketMeow/releases/latest'),
    headers: const {
      'Accept': 'application/json',
      'User-Agent': 'PocketMeow-App',
    },
  );

  final json = jsonDecode(response.body) as Map<String, dynamic>;

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? downloadUrl;
  print('assets: ${json['assets']}');
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
  downloadUrl ??= _readString(json, ['apk_url', 'download_url', 'url']);

  print('downloadUrl: $downloadUrl');

  final detailsUrl =
      _readString(json, ['html_url', 'page_url', 'details_url', 'details']);
  print('detailsUrl: $detailsUrl');
}
