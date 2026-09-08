import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

/// Hive 기반 로컬 저장소 서비스 (개인용 - 클라우드 불필요)
class StorageService {
  static Box? _transactionsBox;
  static Box? _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _transactionsBox = await Hive.openBox(kTransactionsBox);
    _settingsBox = await Hive.openBox(kSettingsBox);
  }

  // ---------------- Transactions ----------------

  static List<CardTransaction> getAllTransactions() {
    final box = _transactionsBox!;
    final list = box.values
        .map((e) => CardTransaction.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  static Future<void> saveTransaction(CardTransaction tx) async {
    await _transactionsBox!.put(tx.id, tx.toMap());
  }

  static Future<void> deleteTransaction(String id) async {
    await _transactionsBox!.delete(id);
  }

  static Future<void> updateTransaction(CardTransaction tx) async {
    await _transactionsBox!.put(tx.id, tx.toMap());
  }

  // ---------------- Team Members (공동사용자 리스트) ----------------

  static List<String> getTeamMembers() {
    final raw = _settingsBox!.get(kSettingsKeyTeamMembers);
    if (raw == null) return <String>[];
    return (raw as List).map((e) => e.toString()).toList();
  }

  static Future<void> addTeamMember(String name) async {
    if (name.trim().isEmpty) return;
    final members = getTeamMembers();
    if (!members.contains(name.trim())) {
      members.add(name.trim());
      await _settingsBox!.put(kSettingsKeyTeamMembers, members);
    }
  }

  static Future<void> addTeamMembers(List<String> names) async {
    final members = getTeamMembers();
    bool changed = false;
    for (final n in names) {
      final trimmed = n.trim();
      if (trimmed.isNotEmpty && !members.contains(trimmed)) {
        members.add(trimmed);
        changed = true;
      }
    }
    if (changed) {
      await _settingsBox!.put(kSettingsKeyTeamMembers, members);
    }
  }

  static Future<void> removeTeamMember(String name) async {
    final members = getTeamMembers();
    members.remove(name);
    await _settingsBox!.put(kSettingsKeyTeamMembers, members);
  }

  // ---------------- Mapping Rules (특정 사용처 자동 매핑) ----------------

  static List<MappingRule> getMappingRules() {
    final raw = _settingsBox!.get(kSettingsKeyMappingRules);
    if (raw == null) {
      // 기본값 초기 세팅
      final defaults = kDefaultMappingRules
          .map(
            (e) => MappingRule(
              keyword: e['keyword']!,
              detail: e['detail']!,
              category: e['category']!,
            ),
          )
          .toList();
      _saveMappingRules(defaults);
      return defaults;
    }
    return (raw as List)
        .map((e) => MappingRule.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  static Future<void> _saveMappingRules(List<MappingRule> rules) async {
    await _settingsBox!.put(
      kSettingsKeyMappingRules,
      rules.map((e) => e.toMap()).toList(),
    );
  }

  static Future<void> addMappingRule(MappingRule rule) async {
    final rules = getMappingRules();
    rules.add(rule);
    await _saveMappingRules(rules);
  }

  static Future<void> updateMappingRuleAt(int index, MappingRule rule) async {
    final rules = getMappingRules();
    if (index >= 0 && index < rules.length) {
      rules[index] = rule;
      await _saveMappingRules(rules);
    }
  }

  static Future<void> removeMappingRuleAt(int index) async {
    final rules = getMappingRules();
    if (index >= 0 && index < rules.length) {
      rules.removeAt(index);
      await _saveMappingRules(rules);
    }
  }
}
