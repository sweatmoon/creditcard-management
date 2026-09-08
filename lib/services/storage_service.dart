import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../utils/api_config.dart';

/// Railway Postgres 기반 REST API 저장소 서비스
///
/// 기존에는 Hive(브라우저 로컬 저장소)를 사용해 PC 웹과 모바일 웹 간
/// 데이터가 동기화되지 않는 문제가 있었다. 이제는 서버(Node.js + Postgres)의
/// REST API(/api/transactions, /api/team-members, /api/mapping-rules)를
/// 통해 모든 데이터를 클라우드 DB에 저장/조회하므로, 어떤 기기/브라우저에서
/// 접속해도 동일한 데이터를 보게 된다.
class StorageService {
  static String get _base => ApiConfig.baseUrl;

  /// 과거 Hive 초기화를 대체하는 자리. 현재는 별도 초기화가 필요 없지만,
  /// 향후 헬스체크 등을 위해 async 함수 형태를 유지한다.
  static Future<void> init() async {
    // no-op: HTTP API는 별도 초기화가 필요 없음
  }

  static Uri _uri(String path) => Uri.parse('$_base$path');

  static Never _fail(String action, Object e) {
    throw Exception('$action 실패: $e');
  }

  // ---------------- Transactions ----------------

  static Future<List<CardTransaction>> getAllTransactions() async {
    try {
      final res = await http.get(_uri('/api/transactions'));
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      final list = data
          .map((e) => CardTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // 최신순으로 받아오지만, 화면에서 필요한 정렬은 각 화면에서 별도로 처리
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (e) {
      _fail('거래내역 조회', e);
    }
  }

  static Future<void> saveTransaction(CardTransaction tx) async {
    try {
      final res = await http.post(
        _uri('/api/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(tx.toJson()),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('거래내역 저장', e);
    }
  }

  static Future<void> updateTransaction(CardTransaction tx) async {
    try {
      final res = await http.put(
        _uri('/api/transactions/${Uri.encodeComponent(tx.id)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(tx.toJson()),
      );
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('거래내역 수정', e);
    }
  }

  static Future<void> deleteTransaction(String id) async {
    try {
      final res = await http.delete(
        _uri('/api/transactions/${Uri.encodeComponent(id)}'),
      );
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('거래내역 삭제', e);
    }
  }

  // ---------------- Team Members (공동사용자 리스트) ----------------

  static Future<List<String>> getTeamMembers() async {
    try {
      final res = await http.get(_uri('/api/team-members'));
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      _fail('팀원 목록 조회', e);
    }
  }

  static Future<void> addTeamMember(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final res = await http.post(
        _uri('/api/team-members'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': trimmed}),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('팀원 추가', e);
    }
  }

  static Future<void> addTeamMembers(List<String> names) async {
    for (final n in names) {
      await addTeamMember(n);
    }
  }

  static Future<void> removeTeamMember(String name) async {
    try {
      final res = await http.delete(
        _uri('/api/team-members/${Uri.encodeComponent(name)}'),
      );
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('팀원 삭제', e);
    }
  }

  // ---------------- Mapping Rules (특정 사용처 자동 매핑) ----------------

  static Future<List<MappingRule>> getMappingRules() async {
    try {
      final res = await http.get(_uri('/api/mapping-rules'));
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data
          .map((e) => MappingRule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _fail('매핑규칙 조회', e);
    }
  }

  static Future<void> addMappingRule(MappingRule rule) async {
    try {
      final res = await http.post(
        _uri('/api/mapping-rules'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(rule.toJson()),
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('매핑규칙 추가', e);
    }
  }

  static Future<void> updateMappingRule(int id, MappingRule rule) async {
    try {
      final res = await http.put(
        _uri('/api/mapping-rules/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(rule.toJson()),
      );
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('매핑규칙 수정', e);
    }
  }

  static Future<void> removeMappingRule(int id) async {
    try {
      final res = await http.delete(_uri('/api/mapping-rules/$id'));
      if (res.statusCode != 200) {
        throw Exception('서버 응답 오류 (${res.statusCode})');
      }
    } catch (e) {
      _fail('매핑규칙 삭제', e);
    }
  }
}
