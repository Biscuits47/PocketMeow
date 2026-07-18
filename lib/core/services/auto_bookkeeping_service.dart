import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'bill_category_mapper.dart';
import '../../app/state/pocket_meow_store.dart';
import '../../data/models/app_models.dart';

class AutoBookkeepingService {
  AutoBookkeepingService(this._store);
  static const MethodChannel _notificationMethodChannel =
      MethodChannel('x-slayer/notifications_channel');
  static const Duration _duplicateWindow = Duration(seconds: 60);
  static const Duration _recentCacheWindow = Duration(minutes: 2);
  static const List<Duration> _warmUpRetryDelays = [
    Duration(milliseconds: 900),
    Duration(seconds: 3),
    Duration(seconds: 7),
  ];
  static bool get _supportsAutoBookkeepingPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final PocketMeowStore _store;

  StreamSubscription? _notificationSub;
  StreamSubscription? _accessibilitySub;
  final List<Timer> _warmUpRetryTimers = [];

  final List<_CapturedTransactionSignature> _recentTransactions = [];
  final Map<String, DateTime> _lastSnapshotTimes = {};
  final Map<String, String> _lastSnapshotKeys = {};

  bool _isListening = false;
  int _startSessionToken = 0;
  bool get isListening => _isListening;

  Future<void> startListening({
    bool forceRestart = false,
    bool scheduleWarmUp = true,
  }) async {
    if (!_supportsAutoBookkeepingPlatform) {
      stopListening();
      return;
    }

    final notifGranted = await _safeNotificationPermissionGranted();
    final accGranted = await _safeAccessibilityPermissionEnabled();
    final hasNotificationSub = _notificationSub != null;
    final hasAccessibilitySub = _accessibilitySub != null;
    if (!forceRestart &&
        _isListening &&
        hasNotificationSub == notifGranted &&
        hasAccessibilitySub == accGranted) {
      return;
    }

    if (hasNotificationSub || hasAccessibilitySub) {
      stopListening();
    }

    var hasSubscription = false;

    if (notifGranted) {
      await _ensureNotificationListenerReady();
      _notificationSub = NotificationListenerService.notificationsStream.listen(
        _onNotification,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('AutoBookkeeping: notification stream error: $error');
        },
      );
      hasSubscription = true;
    }

    if (accGranted) {
      _accessibilitySub = FlutterAccessibilityService.accessStream.listen(
        _onAccessibilityEvent,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('AutoBookkeeping: accessibility stream error: $error');
        },
      );
      hasSubscription = true;
    }

    _isListening = hasSubscription;
    _cancelWarmUpRetries();
    if (!_isListening) {
      debugPrint('AutoBookkeeping: permissions missing, listener not started');
      return;
    }

    if (scheduleWarmUp) {
      _scheduleWarmUpRetries();
    }
  }

  Future<void> restartListening() async {
    stopListening();
    await startListening();
  }

  Future<void> syncListeningWithPermissions() async {
    if (!_supportsAutoBookkeepingPlatform) {
      stopListening();
      return;
    }

    final notifGranted = await _safeNotificationPermissionGranted();
    final accGranted = await _safeAccessibilityPermissionEnabled();

    if (!notifGranted && !accGranted) {
      stopListening();
      return;
    }

    await startListening();
  }

  void stopListening() {
    _cancelWarmUpRetries();
    _notificationSub?.cancel();
    _accessibilitySub?.cancel();
    _notificationSub = null;
    _accessibilitySub = null;
    _lastSnapshotTimes.clear();
    _lastSnapshotKeys.clear();
    _isListening = false;
  }

  void _onNotification(ServiceNotificationEvent event) {
    _startSessionToken++;
    final pkg = event.packageName;
    final title = event.title;
    final content = event.content;

    if (pkg.contains('com.tencent.mm')) {
      _parseWeChat(title, content);
    } else if (pkg.contains('com.eg.android.AlipayGphone')) {
      _parseAlipay(title, content);
    }
  }

  void _onAccessibilityEvent(AccessibilityEvent event) {
    if (event.packageName == null || event.text == null) return;
    _startSessionToken++;

    final pkg = event.packageName!;
    final text = _normalizeAccessibilityText(event.text!) ?? event.text!;
    if (!pkg.contains('com.tencent.mm') &&
        !pkg.contains('com.eg.android.AlipayGphone')) {
      return;
    }

    // Extract all text from subNodes
    final List<String> allNodesText = [];
    void extractText(AccessibilityEvent e) {
      final rawText = e.text;
      final nodeText =
          rawText == null ? null : _normalizeAccessibilityText(rawText);
      if (nodeText != null && nodeText.isNotEmpty && nodeText != 'null') {
        allNodesText.add(nodeText);
      }
      if (e.subNodes != null) {
        for (var sub in e.subNodes!) {
          extractText(sub);
        }
      }
    }

    extractText(event);
    if (allNodesText.isEmpty) return;
    if (!_shouldProcessAccessibilitySnapshot(pkg, text, allNodesText)) return;

    // Accessibility events might capture screen text like "支付成功 ¥ 10.00"
    if (pkg.contains('com.tencent.mm')) {
      _parseWeChatAcc(text, allNodesText);
    } else if (pkg.contains('com.eg.android.AlipayGphone')) {
      _parseAlipayAcc(text, allNodesText);
    }
  }

  void _parseWeChat(String title, String content) {
    final combined = '$title $content';
    final match = _extractNotificationMatch(combined);
    if (match == null) return;
    if (!_containsPaymentKeyword(combined) &&
        !_containsPlatformKeyword(combined, '微信')) {
      return;
    }

    final note = _buildPlatformNote(
      title,
      incomeNote: '微信收款',
      expenseNote: '微信支付',
      genericTitles: const ['微信支付', '微信通知', '微信', '微信支付助手'],
      isIncome: match.type == RecordType.income,
    );
    _addRecordIfUnique(
      match.amount,
      note,
      match.type,
      source: RecordSource.autoWeChat,
    );
  }

  void _parseAlipay(String title, String content) {
    final combined = '$title $content';
    final match = _extractNotificationMatch(combined);
    if (match == null) return;
    if (!_containsPaymentKeyword(combined) &&
        !_containsPlatformKeyword(combined, '支付宝')) {
      return;
    }

    final note = _buildPlatformNote(
      title,
      incomeNote: '支付宝收款',
      expenseNote: '支付宝支付',
      genericTitles: const ['支付宝通知', '支付宝', '支付提醒', '支付宝支付'],
      isIncome: match.type == RecordType.income,
    );
    _addRecordIfUnique(
      match.amount,
      note,
      match.type,
      source: RecordSource.autoAlipay,
    );
  }

  void _parseWeChatAcc(String capturedText, List<String> nodesText) {
    if (capturedText.contains('支付成功') ||
        _containsNodeFragment(nodesText, '支付成功')) {
      _extractAmountAndAdd(
        nodesText,
        '微信支付',
        RecordType.expense,
        null,
        RecordSource.autoWeChat,
      );
    }
    if (_containsNodeFragment(nodesText, '账单详情')) {
      _parseHistoricalBillDetails(nodesText, '微信');
    }
    if (_looksLikeBillList(nodesText, '微信')) {
      _parseHistoricalBillList(nodesText, '微信');
    }
  }

  void _parseAlipayAcc(String capturedText, List<String> nodesText) {
    if (capturedText.contains('支付成功') ||
        _containsNodeFragment(nodesText, '支付成功')) {
      _extractAmountAndAdd(
        nodesText,
        '支付宝支付',
        RecordType.expense,
        null,
        RecordSource.autoAlipay,
      );
    }
    if (_containsNodeFragment(nodesText, '账单详情') ||
        _containsNodeFragment(nodesText, '订单详情')) {
      _parseHistoricalBillDetails(nodesText, '支付宝');
    }
    if (_looksLikeBillList(nodesText, '支付宝')) {
      _parseHistoricalBillList(nodesText, '支付宝');
    }
  }

  void _parseHistoricalBillDetails(List<String> nodesText, String platform) {
    DateTime? parsedTime;
    String? parsedNote;
    String? headerNote;
    String? parsedCategory;
    final amountCandidates = <_AmountCandidate>[];

    for (int i = 0; i < nodesText.length; i++) {
      final text = nodesText[i].trim();
      final candidate = _extractDetailAmountCandidate(nodesText, i);
      if (candidate != null) {
        amountCandidates.add(candidate);
      }

      // Match time (e.g. 2023-10-01 12:00:00 or 2023/10/01 12:00:00)
      final timeRegex = RegExp(r'(\d{4}[-/]\d{2}[-/]\d{2}\s\d{2}:\d{2}:\d{2})');
      final timeMatch = timeRegex.firstMatch(text);
      if (timeMatch != null) {
        final timeStr = timeMatch.group(1)!.replaceAll('/', '-');
        parsedTime = DateTime.tryParse(timeStr);
      }

      // If text is "商品说明" or "商户全称", the next node is usually the note
      if (text == '商品说明' || text == '商户全称' || text == '商品' || text == '交易对方') {
        if (i + 1 < nodesText.length) {
          parsedNote = _sanitizeBillNote(nodesText[i + 1]) ?? parsedNote;
        }
      }

      if (text == '账单分类' && i + 1 < nodesText.length) {
        parsedCategory =
            _sanitizeCategoryText(nodesText[i + 1]) ?? parsedCategory;
      }

      if (headerNote == null && i <= 3) {
        headerNote = _extractDetailHeaderNote(nodesText, i);
      }
    }

    amountCandidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.index.compareTo(b.index);
    });
    final bestCandidate =
        amountCandidates.isNotEmpty ? amountCandidates.first : null;

    if (bestCandidate != null && bestCandidate.amount > 0) {
      _addRecordIfUnique(
        bestCandidate.amount,
        parsedNote ?? headerNote ?? '$platform历史账单',
        bestCandidate.type,
        createdAt: parsedTime,
        source: _sourceForPlatform(platform),
        categoryHint: parsedCategory,
      );
    }
  }

  void _extractAmountAndAdd(List<String> nodesText, String defaultNote,
      RecordType type, DateTime? createdAt, RecordSource source) {
    for (String text in nodesText) {
      final amount = _extractLeadingAmount(text);
      if (amount != null && amount > 0) {
        _addRecordIfUnique(
          amount,
          defaultNote,
          type,
          createdAt: createdAt,
          source: source,
        );
        return;
      }
    }
  }

  void _parseHistoricalBillList(List<String> nodesText, String platform) {
    for (int i = 0; i < nodesText.length; i++) {
      final text = nodesText[i].trim();
      final amount = _extractBillAmount(text);
      if (amount == null || amount <= 0) continue;
      final isSupplementary = _isSupplementaryAmountContext(nodesText, i);
      if (isSupplementary) {
        continue;
      }

      final type = _inferBillListType(nodesText, i, text);
      final note = _findNearbyBillNote(nodesText, i) ?? '$platform历史账单';
      final createdAt = _findNearbyBillTime(nodesText, i);

      _addRecordIfUnique(
        amount,
        note,
        type,
        createdAt: createdAt,
        source: _sourceForPlatform(platform),
      );
    }
  }

  Future<void> _ensureNotificationListenerReady() async {
    if (!_supportsAutoBookkeepingPlatform) {
      return;
    }
    try {
      final connected = await _notificationMethodChannel
              .invokeMethod<bool>('isServiceConnected') ??
          false;
      if (connected) return;
      try {
        await _notificationMethodChannel.invokeMethod('forceRequestRebind');
      } catch (_) {}
      try {
        await _notificationMethodChannel.invokeMethod('reconnectService');
      } catch (_) {}
    } catch (error) {
      debugPrint(
          'AutoBookkeeping: failed to ensure notification service: $error');
    }
  }

  Future<bool> _safeNotificationPermissionGranted() async {
    try {
      return await NotificationListenerService.isPermissionGranted();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _safeAccessibilityPermissionEnabled() async {
    try {
      return await FlutterAccessibilityService
          .isAccessibilityPermissionEnabled();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  void _scheduleWarmUpRetries() {
    _cancelWarmUpRetries();
    final token = ++_startSessionToken;
    for (final delay in _warmUpRetryDelays) {
      _warmUpRetryTimers.add(
        Timer(delay, () async {
          if (token != _startSessionToken ||
              !_store.isAutoBookkeepingEnabled ||
              !_supportsAutoBookkeepingPlatform) {
            return;
          }

          final notifGranted = await _safeNotificationPermissionGranted();
          final accGranted = await _safeAccessibilityPermissionEnabled();
          if (!notifGranted && !accGranted) {
            return;
          }

          await startListening(
            forceRestart: true,
            scheduleWarmUp: false,
          );
        }),
      );
    }
  }

  void _cancelWarmUpRetries() {
    for (final timer in _warmUpRetryTimers) {
      timer.cancel();
    }
    _warmUpRetryTimers.clear();
  }

  bool _containsPaymentKeyword(String text) {
    const keywords = [
      '支付',
      '付款',
      '已支付',
      '支付成功',
      '收款',
      '收款成功',
      '收钱到账',
      '到账',
      '转账',
      '退款',
      '二维码收款',
      '动账',
      '账单',
      '交易',
    ];
    return keywords.any(text.contains);
  }

  bool _looksLikeIncome(String text) {
    return text.contains('收款') ||
        text.contains('到账') ||
        text.contains('退款') ||
        text.contains('转入');
  }

  bool _containsPlatformKeyword(String text, String platform) {
    if (platform == '微信') {
      return text.contains('微信') ||
          text.contains('微信支付') ||
          text.contains('微信支付助手');
    }
    return text.contains('支付宝') || text.contains('支付宝提醒');
  }

  bool _containsNodeFragment(List<String> nodesText, String fragment) {
    return nodesText.any((text) => text.contains(fragment));
  }

  bool _shouldProcessAccessibilitySnapshot(
    String packageName,
    String capturedText,
    List<String> nodesText,
  ) {
    final now = DateTime.now();
    final normalizedText = capturedText.trim();
    final snapshotKey = [
      if (normalizedText.isNotEmpty && normalizedText != 'null') normalizedText,
      ...nodesText.take(24),
    ].join('|');
    final lastKey = _lastSnapshotKeys[packageName];
    final lastTime = _lastSnapshotTimes[packageName];
    _lastSnapshotKeys[packageName] = snapshotKey;
    _lastSnapshotTimes[packageName] = now;
    if (lastTime == null) return true;

    final diffMs = now.difference(lastTime).inMilliseconds;
    if (lastKey == snapshotKey) {
      return diffMs >= 1200;
    }
    return diffMs >= 250;
  }

  bool _looksLikeBillList(List<String> nodesText, String platform) {
    final combined = nodesText.join(' ');
    final hasListKeyword = [
      '全部账单',
      '账单',
      '交易记录',
      '收支记录',
      '筛选',
      '按月',
      '本月',
      '近30天',
      '$platform账单',
    ].any(combined.contains);
    if (!hasListKeyword) return false;

    var amountCount = 0;
    for (final text in nodesText) {
      if (_extractBillAmount(text) != null) {
        amountCount++;
        if (amountCount >= 2) return true;
      }
    }
    return false;
  }

  RecordType _inferBillListType(
      List<String> nodesText, int amountIndex, String amountText) {
    final signed = RegExp(r'^\+').hasMatch(amountText.trim());
    if (signed) return RecordType.income;
    final negative = RegExp(r'^-').hasMatch(amountText.trim());
    if (negative) return RecordType.expense;

    for (int i = amountIndex - 2; i <= amountIndex + 2; i++) {
      if (i < 0 || i >= nodesText.length) continue;
      final probe = nodesText[i];
      if (probe.contains('收款') ||
          probe.contains('到账') ||
          probe.contains('退款')) {
        return RecordType.income;
      }
      if (probe.contains('支付') ||
          probe.contains('付款') ||
          probe.contains('支出')) {
        return RecordType.expense;
      }
    }
    return RecordType.expense;
  }

  String? _findNearbyBillNote(List<String> nodesText, int amountIndex) {
    for (int offset = 1; offset <= 3; offset++) {
      final prev = amountIndex - offset;
      if (prev >= 0) {
        final note = _sanitizeBillNote(nodesText[prev]);
        if (note != null) return note;
      }
    }
    for (int offset = 1; offset <= 2; offset++) {
      final next = amountIndex + offset;
      if (next < nodesText.length) {
        final note = _sanitizeBillNote(nodesText[next]);
        if (note != null) return note;
      }
    }
    return null;
  }

  String? _sanitizeBillNote(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (value == 'null') return null;
    if (_extractBillAmount(value) != null) return null;
    if (_parsePossibleBillTime(value) != null) return null;
    const ignored = [
      '全部账单',
      '账单',
      '账单详情',
      '订单详情',
      '筛选',
      '收入',
      '支出',
      '本月',
      '全部',
      '支付成功',
    ];
    if (ignored.contains(value)) return null;
    if (_containsSupplementaryKeyword(value)) return null;
    if (value.length > 32) return null;
    return value;
  }

  String? _sanitizeCategoryText(String text) {
    final value = text.trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.length > 24) return null;
    return value;
  }

  DateTime? _findNearbyBillTime(List<String> nodesText, int amountIndex) {
    for (int offset = 1; offset <= 4; offset++) {
      final next = amountIndex + offset;
      if (next < nodesText.length) {
        final parsed = _parsePossibleBillTime(nodesText[next]);
        if (parsed != null) return parsed;
      }
      final prev = amountIndex - offset;
      if (prev >= 0) {
        final parsed = _parsePossibleBillTime(nodesText[prev]);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  DateTime? _parsePossibleBillTime(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    final full = RegExp(
            r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?')
        .firstMatch(raw);
    if (full != null) {
      return DateTime(
        int.parse(full.group(1)!),
        int.parse(full.group(2)!),
        int.parse(full.group(3)!),
        int.parse(full.group(4)!),
        int.parse(full.group(5)!),
        int.tryParse(full.group(6) ?? '0') ?? 0,
      );
    }

    final monthDay =
        RegExp(r'(\d{1,2})[-/](\d{1,2})\s+(\d{1,2}):(\d{2})').firstMatch(raw);
    if (monthDay != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        int.parse(monthDay.group(1)!),
        int.parse(monthDay.group(2)!),
        int.parse(monthDay.group(3)!),
        int.parse(monthDay.group(4)!),
      );
    }

    final timeOnly = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (timeOnly != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeOnly.group(1)!),
        int.parse(timeOnly.group(2)!),
      );
    }

    if (raw == '昨天') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (raw == '前天') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - 2);
    }

    return null;
  }

  double? _extractBillAmount(String text) {
    final trimmed = _normalizeAccessibilityText(text) ?? text.trim();
    final signed =
        RegExp(r'^[+-]\s*[¥￥]?\s*(\d+(?:\.\d+)?)$').firstMatch(trimmed);
    if (signed != null) {
      return double.tryParse(signed.group(1)!);
    }
    final keywordAmount = _extractKeywordAmount(trimmed);
    if (keywordAmount != null) {
      return keywordAmount.amount;
    }
    return _extractLeadingAmount(trimmed);
  }

  String? _normalizeAccessibilityText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;

    final spanMatch = RegExp(r'mText:\s*(.*?)\s*\}$').firstMatch(trimmed);
    final candidate = spanMatch?.group(1)?.trim() ?? trimmed;
    if (candidate.isEmpty || candidate == 'null') return null;
    return candidate;
  }

  String _buildPlatformNote(
    String title, {
    required String incomeNote,
    required String expenseNote,
    required List<String> genericTitles,
    required bool isIncome,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || genericTitles.any(trimmed.contains)) {
      return isIncome ? incomeNote : expenseNote;
    }
    return trimmed;
  }

  double? _extractAmountFromText(String text) {
    final patterns = [
      RegExp(r'[¥￥]\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*元'),
      RegExp(r'金额[:：]?\s*[¥￥]?\s*(\d+(?:\.\d{1,2})?)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) {
        continue;
      }
      final amount = double.tryParse(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return amount;
      }
    }
    return null;
  }

  double? _extractLeadingAmount(String text) {
    final match = RegExp(r'^[¥￥]\s*(\d+(?:\.\d+)?)$').firstMatch(text.trim());
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  _KeywordAmountMatch? _extractKeywordAmount(String text) {
    final trimmed = text.trim();
    final match = RegExp(
      r'(支出|收入|收款|付款|支付|到账)\s*[¥￥]?\s*(\d+(?:\.\d+)?)\s*元?',
    ).firstMatch(trimmed);
    if (match == null) return null;

    final amount = double.tryParse(match.group(2)!);
    if (amount == null || amount <= 0) return null;

    final keyword = match.group(1)!;
    final type = (keyword.contains('收入') ||
            keyword.contains('收款') ||
            keyword.contains('到账'))
        ? RecordType.income
        : RecordType.expense;
    return _KeywordAmountMatch(
      amount: amount,
      type: type,
      keyword: keyword,
    );
  }

  _NotificationMatch? _extractNotificationMatch(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final signed = RegExp(r'([+-])\s*[¥￥]?\s*(\d+(?:\.\d{1,2})?)\s*元?')
        .firstMatch(trimmed);
    if (signed != null) {
      final amount = double.tryParse(signed.group(2)!);
      if (amount != null && amount > 0) {
        return _NotificationMatch(
          amount: amount,
          type: signed.group(1) == '+' ? RecordType.income : RecordType.expense,
        );
      }
    }

    final keywordAmount = _extractKeywordAmount(trimmed);
    if (keywordAmount != null) {
      return _NotificationMatch(
        amount: keywordAmount.amount,
        type: keywordAmount.type,
      );
    }

    final amount = _extractAmountFromText(trimmed);
    if (amount == null || amount <= 0) {
      return null;
    }
    return _NotificationMatch(
      amount: amount,
      type: _looksLikeIncome(trimmed) ? RecordType.income : RecordType.expense,
    );
  }

  void _addRecordIfUnique(double amount, String note, RecordType type,
      {DateTime? createdAt, RecordSource? source, String? categoryHint}) {
    final timeToUse = createdAt ?? DateTime.now();
    _cleanupRecentTransactions(timeToUse);

    final signature = _CapturedTransactionSignature(
      amount: amount,
      note: note,
      type: type,
      source: source,
      createdAt: timeToUse,
    );

    if (_hasRecentMemoryDuplicate(signature) ||
        _hasStoredDuplicate(signature)) {
      debugPrint(
          'AutoBookkeeping: Ignored duplicate transaction ${signature.debugKey}');
      return;
    }

    _recentTransactions.add(signature);

    final categoryId = BillCategoryMapper.inferCategoryId(
        note, categoryHint ?? '', type, _store);

    _store.addRecord(
      amount: amount,
      categoryId: categoryId,
      note: note,
      type: type,
      createdAt: timeToUse,
      source: source,
    );

    debugPrint('AutoBookkeeping: Added $type $amount $note');
  }

  void _cleanupRecentTransactions(DateTime now) {
    _recentTransactions.removeWhere(
      (item) => now.difference(item.createdAt) > _recentCacheWindow,
    );
  }

  bool _hasRecentMemoryDuplicate(_CapturedTransactionSignature current) {
    for (final existing in _recentTransactions) {
      if (_isLikelyDuplicate(existing, current)) {
        return true;
      }
    }
    return false;
  }

  bool _hasStoredDuplicate(_CapturedTransactionSignature current) {
    for (final record in _store.records) {
      if (record.source != current.source || record.type != current.type) {
        continue;
      }
      if ((record.amount - current.amount).abs() > 0.009) {
        continue;
      }
      final diff = record.createdAt.difference(current.createdAt).abs();
      if (diff > _duplicateWindow) {
        continue;
      }
      final existing = _CapturedTransactionSignature(
        amount: record.amount,
        note: record.note,
        type: record.type,
        source: record.source,
        createdAt: record.createdAt,
      );
      if (_isLikelyDuplicate(existing, current)) {
        return true;
      }
    }
    return false;
  }

  bool _isLikelyDuplicate(
    _CapturedTransactionSignature existing,
    _CapturedTransactionSignature current,
  ) {
    if (existing.type != current.type || existing.source != current.source) {
      return false;
    }
    if ((existing.amount - current.amount).abs() > 0.009) {
      return false;
    }
    final diff = existing.createdAt.difference(current.createdAt).abs();
    if (diff > _duplicateWindow) {
      return false;
    }

    final existingNote = _normalizeDedupNote(existing.note);
    final currentNote = _normalizeDedupNote(current.note);
    if (existingNote == currentNote) {
      return true;
    }
    if (_isGenericAutoNote(existing.note) || _isGenericAutoNote(current.note)) {
      return true;
    }
    if (existingNote.isEmpty || currentNote.isEmpty) {
      return false;
    }
    return existingNote.contains(currentNote) ||
        currentNote.contains(existingNote);
  }

  String _normalizeDedupNote(String note) {
    final normalized = note
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5A-Za-z0-9]'), '');
    return normalized.toLowerCase();
  }

  bool _isGenericAutoNote(String note) {
    const genericNotes = {
      '微信支付',
      '微信收款',
      '支付宝支付',
      '支付宝收款',
      '微信通知',
      '支付宝通知',
      '微信历史账单',
      '支付宝历史账单',
      '微信',
      '支付宝',
    };
    return genericNotes.contains(note.trim());
  }

  _AmountCandidate? _extractDetailAmountCandidate(
      List<String> nodesText, int index) {
    final text = nodesText[index].trim();
    final signed =
        RegExp(r'^([+-])\s*[¥￥]?\s*(\d+(?:\.\d+)?)$').firstMatch(text);
    final keywordAmount = _extractKeywordAmount(text);
    double? amount;
    RecordType type = RecordType.expense;
    var isPrimaryKeywordAmount = false;

    if (signed != null) {
      amount = double.tryParse(signed.group(2)!);
      type = signed.group(1) == '+' ? RecordType.income : RecordType.expense;
    } else if (keywordAmount != null) {
      amount = keywordAmount.amount;
      type = keywordAmount.type;
      isPrimaryKeywordAmount = true;
    } else {
      amount = _extractLeadingAmount(text);
      if (amount != null) {
        type = _inferBillListType(nodesText, index, text);
      }
    }

    if (amount == null || amount <= 0) return null;

    var score = amount;
    if (index <= 4) score += 40;
    if (_containsNearbyText(nodesText, index, const ['交易成功', '支付成功', '已收款'])) {
      score += 25;
    }
    if (isPrimaryKeywordAmount) {
      score += 120;
    }
    if (signed == null) {
      score += 10;
    }
    if (_isSupplementaryAmountContext(nodesText, index)) {
      score -= 500;
    }

    return _AmountCandidate(
      amount: amount,
      type: type,
      index: index,
      score: score,
    );
  }

  bool _isSupplementaryAmountContext(List<String> nodesText, int amountIndex) {
    for (int i = amountIndex - 2; i <= amountIndex + 2; i++) {
      if (i < 0 || i >= nodesText.length) continue;
      if (_containsSupplementaryKeyword(nodesText[i])) {
        return true;
      }
    }
    return false;
  }

  bool _containsSupplementaryKeyword(String text) {
    const keywords = [
      '抵扣',
      '优惠',
      '立减',
      '红包',
      '优惠券',
      '福利金',
      '积分',
      '返现',
      '补贴',
      '减免',
      '服务费',
      '手续费',
    ];
    return keywords.any(text.contains);
  }

  bool _containsNearbyText(
      List<String> nodesText, int index, List<String> keywords) {
    for (int i = index - 2; i <= index + 2; i++) {
      if (i < 0 || i >= nodesText.length) continue;
      if (keywords.any(nodesText[i].contains)) {
        return true;
      }
    }
    return false;
  }

  String? _extractDetailHeaderNote(List<String> nodesText, int index) {
    final candidate = _sanitizeBillNote(nodesText[index]);
    if (candidate == null) return null;
    if (candidate == '交易成功') return null;
    return candidate;
  }

  RecordSource _sourceForPlatform(String platform) {
    return platform.contains('微信')
        ? RecordSource.autoWeChat
        : RecordSource.autoAlipay;
  }
}

class _AmountCandidate {
  const _AmountCandidate({
    required this.amount,
    required this.type,
    required this.index,
    required this.score,
  });

  final double amount;
  final RecordType type;
  final int index;
  final double score;
}

class _KeywordAmountMatch {
  const _KeywordAmountMatch({
    required this.amount,
    required this.type,
    required this.keyword,
  });

  final double amount;
  final RecordType type;
  final String keyword;
}

class _NotificationMatch {
  const _NotificationMatch({
    required this.amount,
    required this.type,
  });

  final double amount;
  final RecordType type;
}

class _CapturedTransactionSignature {
  const _CapturedTransactionSignature({
    required this.amount,
    required this.note,
    required this.type,
    required this.source,
    required this.createdAt,
  });

  final double amount;
  final String note;
  final RecordType type;
  final RecordSource? source;
  final DateTime createdAt;

  String get debugKey =>
      '${source?.key ?? 'unknown'}|${type.key}|${amount.toStringAsFixed(2)}|$note';
}
