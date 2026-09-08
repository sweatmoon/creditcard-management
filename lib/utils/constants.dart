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

/// 카드 "승인" 문자가 아닌 것으로 간주해 자동으로 걸러내야 하는 안내성 문자 키워드
/// 예) "[롯데법인] 제****호님 09/04기준 1,960,371원 09/14 결제예정(국민)|"
///     -> 결제(청구) 예정 안내 문자로, 개별 승인 내역이 아니므로 제외해야 함
const List<String> kNonApprovalNoticeKeywords = [
  '결제예정',
  '결제 예정',
  '출금예정',
  '출금 예정',
  '청구예정',
  '청구 예정',
  '이용대금',
  '명세서',
  '결제일',
  '연체',
  '자동이체',
  '카드대금',
];
