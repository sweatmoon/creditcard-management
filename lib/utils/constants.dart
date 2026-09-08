// 앱 전역 상수 정의

/// 계정과목 목록
const List<String> kCategories = [
  '식대',
  '교통비(기차)',
  '교통비(고속버스)',
  '교통비(자가용 - 주유비)',
  '교통비(자가용 - 통행료)',
  '숙박비',
  '다과비',
  '기타',
];

/// 식대로 간주하는 점심시간대
const int kLunchStartMinutes = 11 * 60 + 30; // 11:30
const int kLunchEndMinutes = 14 * 60; // 14:00

/// 기본 특정 사용처 매핑 규칙 (사용자가 설정 화면에서 추가/수정/삭제 가능)
const List<Map<String, String>> kDefaultMappingRules = [
  {'keyword': 'GENSPARK.AI', 'detail': 'AI 서비스 구독료', 'category': '기타'},
  {'keyword': 'RAILWAY', 'detail': '서버 호스팅비', 'category': '기타'},
  {'keyword': 'ANTHROPIC', 'detail': 'AI API 사용료', 'category': '기타'},
];

/// Hive box 이름
const String kTransactionsBox = 'transactions_box';
const String kSettingsBox = 'settings_box';

/// Hive settings box 키
const String kSettingsKeyTeamMembers = 'team_members';
const String kSettingsKeyMappingRules = 'mapping_rules';
