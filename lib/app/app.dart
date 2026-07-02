import 'package:flutter/material.dart';

import 'state/pocket_meow_store.dart';
import '../features/add_expense/add_expense_sheet.dart';
import '../features/data/data_page.dart';
import '../features/records/records_page.dart';
import 'theme/app_theme.dart';

class PocketMeowApp extends StatefulWidget {
  const PocketMeowApp({super.key});

  @override
  State<PocketMeowApp> createState() => _PocketMeowAppState();
}

class _PocketMeowAppState extends State<PocketMeowApp> {
  late final PocketMeowStore _store;

  @override
  void initState() {
    super.initState();
    _store = PocketMeowStore()..load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PocketMeowScope(
      notifier: _store,
      child: MaterialApp(
        title: '钱喵',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
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

  final List<Widget> _pages = const [
    RecordsPage(),
    DataPage(),
  ];

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

    return Scaffold(
      extendBody: true,
      body: store.isReady
          ? IndexedStack(
              index: _currentIndex,
              children: _pages,
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
