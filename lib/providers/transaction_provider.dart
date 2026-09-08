import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../services/sms_parser.dart';
import '../services/storage_service.dart';

/// 앱 전역 상태 관리 (거래내역, 팀원, 매핑규칙)
class TransactionProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<CardTransaction> _transactions = [];
  List<String> _teamMembers = [];
  List<MappingRule> _mappingRules = [];

  List<CardTransaction> get transactions => _transactions;
  List<String> get teamMembers => _teamMembers;
  List<MappingRule> get mappingRules => _mappingRules;

  void loadAll() {
    _transactions = StorageService.getAllTransactions();
    _teamMembers = StorageService.getTeamMembers();
    _mappingRules = StorageService.getMappingRules();
    notifyListeners();
  }

  /// SMS 원문을 파싱하여 미리보기용 결과를 생성 (저장 전 사용자 확인용)
  ParsedSmsPreview parseSms(String rawMessage) {
    final parsed = SmsParser.parse(rawMessage);
    if (!parsed.success) {
      return ParsedSmsPreview(success: false, rawMessage: rawMessage);
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
      _teamMembers = StorageService.getTeamMembers();
    }

    _transactions = StorageService.getAllTransactions();
    notifyListeners();
  }

  Future<void> updateTransaction(CardTransaction tx) async {
    await StorageService.updateTransaction(tx);
    if (tx.coUsers.isNotEmpty) {
      await StorageService.addTeamMembers(tx.coUsers);
      _teamMembers = StorageService.getTeamMembers();
    }
    _transactions = StorageService.getAllTransactions();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await StorageService.deleteTransaction(id);
    _transactions = StorageService.getAllTransactions();
    notifyListeners();
  }

  Future<void> addTeamMember(String name) async {
    await StorageService.addTeamMember(name);
    _teamMembers = StorageService.getTeamMembers();
    notifyListeners();
  }

  Future<void> removeTeamMember(String name) async {
    await StorageService.removeTeamMember(name);
    _teamMembers = StorageService.getTeamMembers();
    notifyListeners();
  }

  Future<void> addMappingRule(MappingRule rule) async {
    await StorageService.addMappingRule(rule);
    _mappingRules = StorageService.getMappingRules();
    notifyListeners();
  }

  Future<void> updateMappingRuleAt(int index, MappingRule rule) async {
    await StorageService.updateMappingRuleAt(index, rule);
    _mappingRules = StorageService.getMappingRules();
    notifyListeners();
  }

  Future<void> removeMappingRuleAt(int index) async {
    await StorageService.removeMappingRuleAt(index);
    _mappingRules = StorageService.getMappingRules();
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
  });
}
