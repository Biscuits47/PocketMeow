import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app/app.dart';

void _reportDebugEvent({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const {},
}) {
  (() async {
    var serverUrl = 'http://192.168.31.33:7777/event';
    const sessionId = 'auto-bookkeeping-crash';
    try {
      final env = await File('.dbg/auto-bookkeeping-crash.env').readAsString();
      for (final line in env.split('\n')) {
        if (line.startsWith('DEBUG_SERVER_URL=')) {
          serverUrl = line.substring('DEBUG_SERVER_URL='.length).trim();
        }
      }
    } catch (_) {}
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(serverUrl));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'sessionId': sessionId,
        'runId': 'post-fix',
        'hypothesisId': hypothesisId,
        'location': location,
        'msg': '[DEBUG] $message',
        'data': data,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }));
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  })();
}

void main() {
  // #region debug-point E:flutter-error
  FlutterError.onError = (details) {
    _reportDebugEvent(
      hypothesisId: 'E',
      location: 'main.dart:FlutterError.onError',
      message: 'Caught Flutter framework error',
      data: {
        'exception': details.exceptionAsString(),
        'library': details.library,
        'context': details.context?.toDescription(),
        'stack': details.stack?.toString(),
      },
    );
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    _reportDebugEvent(
      hypothesisId: 'E',
      location: 'main.dart:PlatformDispatcher.onError',
      message: 'Caught unhandled platform error',
      data: {
        'error': error.toString(),
        'stack': stack.toString(),
      },
    );
    return false;
  };
  // #endregion
  runApp(const PocketMeowApp());
}
