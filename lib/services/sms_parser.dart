import '../models/transaction.dart';
import '../utils/constants.dart';

/// SMS 문자 파싱 결과
class ParsedSms {
  final String? merchant;
  final double? amount;
  final DateTime? dateTime;
  final String? cardHolder;
  final String? cardInfo;
  final bool success;

  ParsedSms({
    this.merchant,
    this.amount,
    this.dateTime,
    this.cardHolder,
    this.cardInfo,
    required this.success,
  });

  factory ParsedSms.failure() => ParsedSms(success: false);
}

/// 카드사 승인 문자 파싱 서비스
///
/// 지원 형식 예시 (롯데카드 등 세로형 문자):
/// ```
/// [Web발신]
/// 취향마
/// 69,700원 승인
/// 제안 김현호 롯데법인7283
/// 일시불 05/15 11:50
/// 누적2,379,996원
/// ```
class SmsParser {
  // 세로형(줄바꿈) 금액+승인 라인 패턴: "69,700원 승인"
  static final RegExp _amountLineRegex = RegExp(
    r'^([0-9][0-9,]*)\s*원\s*(승인|취소|매출)$',
  );

  // 카드명의자 + 카드정보 라인 패턴: "제안 김현호 롯데법인7283"
  static final RegExp _cardHolderLineRegex = RegExp(
    r'^(\S+)\s+([가-힣]{2,4})\s+(\S+)$',
  );

  // 날짜/시간 패턴: "05/15 11:50"
  static final RegExp _dateTimeRegex = RegExp(
    r'(\d{1,2})[/.](\d{1,2})\D{1,4}(\d{1,2}):(\d{2})',
  );

  // 일반적인(가로형) 금액 패턴: "150,000원"
  static final RegExp _genericAmountRegex = RegExp(r'([0-9][0-9,]*)\s*원');

  /// 카드 승인 문자로 보이는지 여부 (필터링용)
  static bool looksLikeCardApproval(String message) {
    return message.contains('원') &&
        (message.contains('승인') || message.contains('매출'));
  }

  /// 문자 본문을 파싱하여 사용처/금액/일시/카드명의자 등을 추출
  static ParsedSms parse(String rawMessage) {
    if (!looksLikeCardApproval(rawMessage)) {
      return ParsedSms.failure();
    }

    final lines = rawMessage
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !RegExp(r'^\[.*발신\]$').hasMatch(e))
        .toList();

    String? merchant;
    double? amount;
    DateTime? dateTime;
    String? cardHolder;
    String? cardInfo;

    // 1) 세로형 포맷 우선 시도: "금액원 승인" 라인을 찾는다
    int amountLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final m = _amountLineRegex.firstMatch(lines[i]);
      if (m != null) {
        amount = _parseAmount(m.group(1));
        amountLineIndex = i;
        break;
      }
    }

    if (amountLineIndex > 0) {
      // 금액 라인 바로 위 줄을 사용처로 간주
      final candidate = lines[amountLineIndex - 1];
      // 사용처로 보기 어려운 패턴(날짜/카드정보 등)이 아니면 채택
      if (!_dateTimeRegex.hasMatch(candidate) &&
          !_cardHolderLineRegex.hasMatch(candidate)) {
        merchant = candidate;
      }
    }

    // 2) 카드명의자 + 카드정보 라인 탐색
    for (final line in lines) {
      final m = _cardHolderLineRegex.firstMatch(line);
      if (m != null) {
        cardHolder = m.group(2);
        cardInfo = m.group(3);
        break;
      }
    }

    // 3) 날짜/시간 탐색 (전체 텍스트 대상)
    final dtMatch = _dateTimeRegex.firstMatch(rawMessage);
    if (dtMatch != null) {
      final month = int.tryParse(dtMatch.group(1) ?? '') ?? 1;
      final day = int.tryParse(dtMatch.group(2) ?? '') ?? 1;
      final hour = int.tryParse(dtMatch.group(3) ?? '') ?? 0;
      final minute = int.tryParse(dtMatch.group(4) ?? '') ?? 0;
      final now = DateTime.now();
      var year = now.year;
      var candidate = DateTime(year, month, day, hour, minute);
      // 미래 날짜로 계산되면 작년으로 보정 (연도 정보가 없는 문자 특성상)
      if (candidate.isAfter(now.add(const Duration(days: 1)))) {
        candidate = DateTime(year - 1, month, day, hour, minute);
      }
      dateTime = candidate;
    }

    // 4) 세로형에서 금액을 못 찾았다면 일반(가로형) 문자 형식으로 재시도
    if (amount == null) {
      // "누적" 금액 라인은 제외하고 첫 번째 금액을 채택
      for (final line in lines) {
        if (line.contains('누적')) continue;
        final m = _genericAmountRegex.firstMatch(line);
        if (m != null) {
          amount = _parseAmount(m.group(1));
          break;
        }
      }
    }

    if (merchant == null || merchant.isEmpty) {
      // 사용처를 특정하지 못한 경우, 승인/금액/날짜/카드정보 라인을 제외한
      // 첫 번째 남은 줄을 사용처 후보로 사용
      for (final line in lines) {
        if (_amountLineRegex.hasMatch(line)) continue;
        if (_dateTimeRegex.hasMatch(line)) continue;
        if (_cardHolderLineRegex.hasMatch(line)) continue;
        if (line.contains('누적')) continue;
        merchant = line;
        break;
      }
    }

    final success = amount != null && amount > 0;

    return ParsedSms(
      merchant: merchant,
      amount: amount,
      dateTime: dateTime ?? DateTime.now(),
      cardHolder: cardHolder,
      cardInfo: cardInfo,
      success: success,
    );
  }

  static double? _parseAmount(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  /// 점심시간대(11:30~14:00) 여부 판단 -> 식대 자동분류 기준
  static bool isLunchTime(DateTime dateTime) {
    final minutes = dateTime.hour * 60 + dateTime.minute;
    return minutes >= kLunchStartMinutes && minutes <= kLunchEndMinutes;
  }

  /// 특정 사용처 키워드 매핑 규칙 적용
  /// 매칭되면 (category, detail)을 반환, 매칭 안되면 null
  static MappingRule? findMappingRule(
    String merchant,
    String rawMessage,
    List<MappingRule> rules,
  ) {
    final target = ('$merchant $rawMessage').toUpperCase();
    for (final rule in rules) {
      if (rule.keyword.isEmpty) continue;
      if (target.contains(rule.keyword.toUpperCase())) {
        return rule;
      }
    }
    return null;
  }

  /// 자동 분류 로직: 식대(점심시간) > 매핑규칙 > 기타
  /// 반환: (category, detail, isMealSuggested)
  static ClassificationResult classify({
    required DateTime dateTime,
    required String merchant,
    required String rawMessage,
    required List<MappingRule> mappingRules,
  }) {
    // 1) 매핑 규칙이 우선 적용 (특정 사용처는 항상 지정된 값으로)
    final rule = findMappingRule(merchant, rawMessage, mappingRules);
    if (rule != null) {
      return ClassificationResult(
        category: rule.category,
        detail: rule.detail,
        isMealSuggested: false,
      );
    }

    // 2) 점심시간대(11:30~14:00)이면 식대로 자동분류 제안
    if (isLunchTime(dateTime)) {
      return ClassificationResult(
        category: '식대',
        detail: '',
        isMealSuggested: true,
      );
    }

    // 3) 기본값
    return ClassificationResult(
      category: '기타',
      detail: '',
      isMealSuggested: false,
    );
  }
}

class ClassificationResult {
  final String category;
  final String detail;
  final bool isMealSuggested;

  ClassificationResult({
    required this.category,
    required this.detail,
    required this.isMealSuggested,
  });
}
