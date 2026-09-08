import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../services/sms_parser.dart';
import '../services/storage_service.dart';

/// 앱 전역 상태 관리 (거래내역, 팀원, 매핑규칙)
///
/// 데이터는 Railway Postgres에 저장되며, StorageService를 통해 HTTP API로
/// 조회/저장한다. 따라서 PC 웹과 모바일 웹이 동일한 서버(DB)를 바라보게 되어
/// 어느 기기에서 입력하든 데이터가 자동으로 동기화된다.
class TransactionProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<CardTransaction> _transactions = [];
  List<String> _teamMembers = [];
  List<MappingRule> _mappingRules = [];
  List<PendingSms> _pendingSms = [];

  bool _isLoading = false;
  String? _error;

  List<CardTransaction> get transactions => _transactions;
  List<String> get teamMembers => _teamMembers;
  List<MappingRule> get mappingRules => _mappingRules;
  List<PendingSms> get pendingSms => _pendingSms;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 서버(Railway Postgres)에서 전체 데이터를 새로 불러온다.
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        StorageService.getAllTransactions(),
        StorageService.getTeamMembers(),
        StorageService.getMappingRules(),
        StorageService.getPendingSms(),
      ]);
      _transactions = results[0] as List<CardTransaction>;
      _teamMembers = results[1] as List<String>;
      _mappingRules = results[2] as List<MappingRule>;
      _pendingSms = results[3] as List<PendingSms>;
      _error = null;
    } catch (e) {
      _error = '데이터를 불러오지 못했습니다: $e';
      if (kDebugMode) {
        debugPrint('TransactionProvider.loadAll error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 검토 대기 목록만 새로고침 (홈 화면 배지 등에서 가볍게 사용)
  Future<void> refreshPendingSms() async {
    try {
      _pendingSms = await StorageService.getPendingSms();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('refreshPendingSms error: $e');
    }
  }

  /// 검토 대기 항목 승인 -> 실제 거래로 저장
  Future<void> approvePendingSms(
    PendingSms pending, {
    required String merchant,
    required double amount,
    required String currency,
    required String category,
    required String detail,
    required List<String> coUsers,
    required DateTime dateTime,
    String? cardHolder,
  }) async {
    await StorageService.approvePendingSms(
      pending.id,
      merchant: merchant,
      amount: amount,
      currency: currency,
      category: category,
      detail: detail,
      coUsers: coUsers,
      dateTime: dateTime,
      cardHolder: cardHolder,
    );
    if (coUsers.isNotEmpty) {
      await StorageService.addTeamMembers(coUsers);
      _teamMembers = await StorageService.getTeamMembers();
    }
    _transactions = await StorageService.getAllTransactions();
    _pendingSms = await StorageService.getPendingSms();
    notifyListeners();
  }

  /// 검토 대기 항목 거부(무시)
  Future<void> rejectPendingSms(PendingSms pending) async {
    await StorageService.rejectPendingSms(pending.id);
    _pendingSms = await StorageService.getPendingSms();
    notifyListeners();
  }

  /// SMS 원문을 파싱하여 미리보기용 결과를 생성 (저장 전 사용자 확인용)
  ParsedSmsPreview parseSms(String rawMessage) {
    final parsed = SmsParser.parse(rawMessage);
    if (!parsed.success) {
      return ParsedSmsPreview(
        success: false,
        rawMessage: rawMessage,
        rejectReason: parsed.rejectReason,
      );
    }

    final dateTime = parsed.dateTime ?? DateTime.now();
    final rawMerchant = parsed.merchant ?? '알 수 없음';

    final classification = SmsParser.classify(
      dateTime: dateTime,
      merchant: rawMerchant,
      rawMessage: rawMessage,
      mappingRules: _mappingRules,
      isOverseas: parsed.isOverseas,
    );

    // 해외승인 문자에서 접두어(prefix) 매칭으로 사용처가 확정된 경우,
    // 잘린 사용처("G", "ANT" 등) 대신 정식 키워드("GENSPARK.AI")로 교정
    final merchant = classification.matchedKeyword ?? rawMerchant;

    return ParsedSmsPreview(
      success: true,
      rawMessage: rawMessage,
      merchant: merchant,
      amount: parsed.amount ?? 0,
      currency: parsed.currency,
      dateTime: dateTime,
      cardHolder: parsed.cardHolder,
      category: classification.category,
      detail: classification.detail,
      isMealSuggested: classification.isMealSuggested,
      isOverseas: parsed.isOverseas,
      autoMatched: classification.matchedKeyword != null,
    );
  }

  Future<void> addTransaction({
    required String merchant,
    required double amount,
    required String category,
    required String detail,
    required List<String> coUsers,
    required DateTime dateTime,
    String currency = 'KRW',
    String? cardHolder,
    required String rawMessage,
  }) async {
    final tx = CardTransaction(
      id: _uuid.v4(),
      merchant: merchant,
      amount: amount,
      currency: currency,
      category: category,
      detail: detail,
      coUsers: coUsers,
      dateTime: dateTime,
      cardHolder: cardHolder,
      rawMessage: rawMessage,
      createdAt: DateTime.now(),
    );
    await StorageService.saveTransaction(tx);

    // 공동사용자 중 리스트에 없는 신규 인원 자동 등록
    if (coUsers.isNotEmpty) {
      await StorageService.addTeamMembers(coUsers);
      _teamMembers = await StorageService.getTeamMembers();
    }

    _transactions = await StorageService.getAllTransactions();
    notifyListeners();
  }

  Future<void> updateTransaction(CardTransaction tx) async {
    await StorageService.updateTransaction(tx);
    if (tx.coUsers.isNotEmpty) {
      await StorageService.addTeamMembers(tx.coUsers);
      _teamMembers = await StorageService.getTeamMembers();
    }
    _transactions = await StorageService.getAllTransactions();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await StorageService.deleteTransaction(id);
    _transactions = await StorageService.getAllTransactions();
    notifyListeners();
  }

  Future<void> addTeamMember(String name) async {
    await StorageService.addTeamMember(name);
    _teamMembers = await StorageService.getTeamMembers();
    notifyListeners();
  }

  Future<void> removeTeamMember(String name) async {
    await StorageService.removeTeamMember(name);
    _teamMembers = await StorageService.getTeamMembers();
    notifyListeners();
  }

  Future<void> addMappingRule(MappingRule rule) async {
    await StorageService.addMappingRule(rule);
    _mappingRules = await StorageService.getMappingRules();
    notifyListeners();
  }

  /// rule.id가 있는(=서버에 이미 존재하는) 규칙을 수정
  Future<void> updateMappingRule(MappingRule rule) async {
    if (rule.id == null) return;
    await StorageService.updateMappingRule(rule.id!, rule);
    _mappingRules = await StorageService.getMappingRules();
    notifyListeners();
  }

  /// rule.id가 있는(=서버에 이미 존재하는) 규칙을 삭제
  Future<void> removeMappingRule(MappingRule rule) async {
    if (rule.id == null) return;
    await StorageService.removeMappingRule(rule.id!);
    _mappingRules = await StorageService.getMappingRules();
    notifyListeners();
  }

  // ---------------- 통계 helper (통화별로 분리 집계) ----------------

  /// 이번달 통화별 합계. 예: {'KRW': 1234500, 'USD': 243.95}
  Map<String, double> get thisMonthTotalByCurrency {
    final now = DateTime.now();
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t.dateTime.year == now.year && t.dateTime.month == now.month) {
        map[t.currency] = (map[t.currency] ?? 0) + t.amount;
      }
    }
    return map;
  }

  /// 이번달 원화(KRW) 합계만 (기존 호환용 - 홈 화면 대표 숫자)
  double get thisMonthTotal {
    return thisMonthTotalByCurrency['KRW'] ?? 0;
  }

  Map<String, double> get thisMonthByCategory {
    final now = DateTime.now();
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t.dateTime.year == now.year &&
          t.dateTime.month == now.month &&
          t.currency == 'KRW') {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    return map;
  }

  List<CardTransaction> transactionsForMonth(int year, int month) {
    return _transactions
        .where((t) => t.dateTime.year == year && t.dateTime.month == month)
        .toList();
  }
}

class ParsedSmsPreview {
  final bool success;
  final String rawMessage;
  final String? merchant;
  final double amount;
  final String currency;
  final DateTime? dateTime;
  final String? cardHolder;
  final String category;
  final String detail;
  final bool isMealSuggested;
  final bool isOverseas;
  final bool autoMatched; // 해외 prefix 매칭 등으로 사용처가 자동 확정된 경우
  final String? rejectReason; // 파싱 실패 시, 왜 거부되었는지 사용자에게 안내할 문구

  ParsedSmsPreview({
    required this.success,
    required this.rawMessage,
    this.merchant,
    this.amount = 0,
    this.currency = 'KRW',
    this.dateTime,
    this.cardHolder,
    this.category = '기타',
    this.detail = '',
    this.isMealSuggested = false,
    this.isOverseas = false,
    this.autoMatched = false,
    this.rejectReason,
  });
}
