import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/pocket_meow_store.dart';
import '../features/add_expense/add_expense_sheet.dart';
import '../features/data/data_page.dart';
import '../features/records/records_page.dart';
import '../features/settings/settings_page.dart';
import 'theme/app_theme.dart';

void _reportAppDebugEvent({
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

class PocketMeowApp extends StatefulWidget {
  const PocketMeowApp({super.key});

  @override
  State<PocketMeowApp> createState() => _PocketMeowAppState();
}

class _PocketMeowAppState extends State<PocketMeowApp>
    with WidgetsBindingObserver {
  late final PocketMeowStore _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = PocketMeowStore()..load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // #region debug-point A:lifecycle-resumed
    _reportAppDebugEvent(
      hypothesisId: 'A',
      location: 'app.dart:didChangeAppLifecycleState',
      message: 'App lifecycle changed',
      data: {
        'state': state.name,
        'isReady': _store.isReady,
        'autoBookkeepingEnabled': _store.isAutoBookkeepingEnabled,
      },
    );
    // #endregion
    if (state != AppLifecycleState.resumed ||
        !_store.isReady ||
        !_store.isAutoBookkeepingEnabled) {
      return;
    }
    unawaited(_store.refreshAutoBookkeepingListening());
  }

  @override
  Widget build(BuildContext context) {
    return PocketMeowScope(
      notifier: _store,
      child: MaterialApp(
        title: '钱喵',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
        ],
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _hasTriggeredStartupUpdateCheck = false;
  bool _hasPlayedDataIntroAnimation = false;
  int _dataIntroAnimationToken = 0;

  void _openAddExpense() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PocketMeowScope.watch(context);

    if (store.isReady && !_hasTriggeredStartupUpdateCheck) {
      _hasTriggeredStartupUpdateCheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          checkForUpdatesAndPrompt(
            context,
            respectIgnoredRelease: true,
          ),
        );
      });
    }

    return Scaffold(
      extendBody: true,
      body: store.isReady
          ? IndexedStack(
              index: _currentIndex,
              children: [
                const RecordsPage(),
                DataPage(introAnimationToken: _dataIntroAnimationToken),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                strokeCap: StrokeCap.round,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpense,
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          height: 76,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              if (index == 1 && !_hasPlayedDataIntroAnimation) {
                _hasPlayedDataIntroAnimation = true;
                _dataIntroAnimationToken++;
              }
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: '账单',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: '数据',
            ),
          ],
        ),
      ),
    );
  }
}
