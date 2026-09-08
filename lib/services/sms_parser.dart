import '../models/transaction.dart';
import '../utils/constants.dart';

/// SMS 문자 파싱 결과
class ParsedSms {
  final String? merchant;
  final double? amount;
  final String currency; // KRW, USD 등
  final DateTime? dateTime;
  final String? cardHolder;
  final String? cardInfo;
  final bool isOverseas; // 해외승인 문자 여부 (사용처가 심하게 잘리는 특성)
  final bool success;
  final String? rejectReason; // 승인 문자가 아니라고 판단된 이유 (사용자 안내용)

  ParsedSms({
    this.merchant,
    this.amount,
    this.currency = 'KRW',
    this.dateTime,
    this.cardHolder,
    this.cardInfo,
    this.isOverseas = false,
    required this.success,
    this.rejectReason,
  });

  factory ParsedSms.failure({String? reason}) =>
      ParsedSms(success: false, rejectReason: reason);
}

/// 카드사 승인 문자 파싱 서비스
///
/// 지원 형식 예시 1 (롯데카드 등 국내 세로형 문자):
/// ```
/// [Web발신]
/// 취향마
/// 69,700원 승인
/// 제안 김현호 롯데법인7283
/// 일시불 05/15 11:50
/// 누적2,379,996원
/// ```
///
/// 지원 형식 예시 2 (해외승인 - 사용처가 심하게 잘림, 통화는 USD 등):
/// ```
/// [Web발신]
/// GE
/// USD 109.99 해외승인
/// 제안 김현호 롯데법인7283
/// 일시불 08/08 21:43
/// 누적937,460원
/// ```
class SmsParser {
  // 세로형(줄바꿈) 금액+승인 라인 패턴 (국내): "69,700원 승인"
  static final RegExp _amountLineRegex = RegExp(
    r'^([0-9][0-9,]*)\s*원\s*(승인|취소|매출)$',
  );

  // 해외승인 금액 라인 패턴: "USD 109.99 해외승인"
  static final RegExp _overseasAmountLineRegex = RegExp(
    r'^([A-Z]{2,3})\s+([0-9][0-9,]*\.?[0-9]*)\s*해외\s*(승인|취소|매출)$',
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

  /// 결제(청구) 예정 안내, 명세서 안내 등 "개별 승인 내역"이 아닌 안내성 문자인지 판단
  ///
  /// 예) "[롯데법인] 제****호님 09/04기준 1,960,371원 09/14 결제예정(국민)|"
  ///     -> 이번달 전체 청구 예정 금액을 알려주는 안내 문자로, 실제 승인/매출 문자가 아님
  static bool isNonApprovalNotice(String message) {
    final upper = message.toUpperCase();
    return kNonApprovalNoticeKeywords.any(
      (kw) => upper.contains(kw.toUpperCase()),
    );
  }

  /// 카드 승인 문자로 보이는지 여부 (필터링용)
  static bool looksLikeCardApproval(String message) {
    // 결제예정/명세서 등 안내성 문자는 "승인"/"매출" 단어가 없어도, 혹은 우연히
    // 포함되어 있어도 개별 거래 승인 문자가 아니므로 항상 먼저 걸러낸다.
    if (isNonApprovalNotice(message)) return false;

    final hasApprovalWord = message.contains('승인') || message.contains('매출');
    final hasKrwAmount = message.contains('원');
    final hasOverseasAmount = _overseasAmountLineRegex.hasMatch(
      message
          .split('\n')
          .map((e) => e.trim())
          .firstWhere(
            (l) => _overseasAmountLineRegex.hasMatch(l),
            orElse: () => '',
          ),
    );
    return hasApprovalWord && (hasKrwAmount || hasOverseasAmount);
  }

  /// 문자 본문을 파싱하여 사용처/금액/일시/카드명의자 등을 추출
  static ParsedSms parse(String rawMessage) {
    if (isNonApprovalNotice(rawMessage)) {
      return ParsedSms.failure(
        reason: '카드 승인 문자가 아닌 결제(청구) 예정 안내 문자로 보입니다. 개별 승인 문자를 입력해주세요.',
      );
    }
    if (!looksLikeCardApproval(rawMessage)) {
      return ParsedSms.failure(reason: '카드 승인 문자 형식을 인식하지 못했습니다.');
    }

    final lines = rawMessage
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !RegExp(r'^\[.*발신\]$').hasMatch(e))
        .toList();

    String? merchant;
    double? amount;
    String currency = 'KRW';
    DateTime? dateTime;
    String? cardHolder;
    String? cardInfo;
    bool isOverseas = false;

    // 1) 해외승인 패턴 우선 시도: "USD 109.99 해외승인"
    int amountLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final m = _overseasAmountLineRegex.firstMatch(lines[i]);
      if (m != null) {
        currency = m.group(1) ?? 'USD';
        amount = _parseAmount(m.group(2));
        amountLineIndex = i;
        isOverseas = true;
        break;
      }
    }

    // 2) 국내 세로형 포맷 시도: "69,700원 승인"
    if (amountLineIndex == -1) {
      for (int i = 0; i < lines.length; i++) {
        final m = _amountLineRegex.firstMatch(lines[i]);
        if (m != null) {
          amount = _parseAmount(m.group(1));
          amountLineIndex = i;
          currency = 'KRW';
          break;
        }
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

    // 3) 카드명의자 + 카드정보 라인 탐색
    for (final line in lines) {
      final m = _cardHolderLineRegex.firstMatch(line);
      if (m != null) {
        cardHolder = m.group(2);
        cardInfo = m.group(3);
        break;
      }
    }

    // 4) 날짜/시간 탐색 (전체 텍스트 대상)
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

    // 5) 세로형에서 금액을 못 찾았다면 일반(가로형) 문자 형식으로 재시도
    if (amount == null) {
      // "누적" 금액 라인은 제외하고 첫 번째 금액을 채택
      for (final line in lines) {
        if (line.contains('누적')) continue;
        final m = _genericAmountRegex.firstMatch(line);
        if (m != null) {
          amount = _parseAmount(m.group(1));
          currency = 'KRW';
          break;
        }
      }
    }

    if (merchant == null || merchant.isEmpty) {
      // 사용처를 특정하지 못한 경우, 승인/금액/날짜/카드정보 라인을 제외한
      // 첫 번째 남은 줄을 사용처 후보로 사용
      for (final line in lines) {
        if (_amountLineRegex.hasMatch(line)) continue;
        if (_overseasAmountLineRegex.hasMatch(line)) continue;
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
      currency: currency,
      dateTime: dateTime ?? DateTime.now(),
      cardHolder: cardHolder,
      cardInfo: cardInfo,
      isOverseas: isOverseas,
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
  ///
  /// - 국내 문자: 사용처/원문에 키워드가 "포함"되어 있으면 매칭 (기존 방식)
  /// - 해외승인 문자: 사용처 이름이 카드사 문자 바이트 제한으로 심하게 잘려서
  ///   ("GENSPARK.AI" -> "GE" 또는 "G" 등) 완전한 키워드가 나타나지 않으므로,
  ///   잘린 사용처가 등록된 키워드의 "앞부분(prefix)"과 일치하면 매칭 처리한다.
  static MappingRule? findMappingRule(
    String merchant,
    String rawMessage,
    List<MappingRule> rules, {
    bool isOverseas = false,
  }) {
    final target = ('$merchant $rawMessage').toUpperCase();
    final trimmedMerchant = merchant.trim().toUpperCase();

    for (final rule in rules) {
      if (rule.keyword.isEmpty) continue;
      final keyword = rule.keyword.toUpperCase();

      // 1) 일반 포함 매칭 (국내 문자 등 사용처가 온전한 경우)
      if (target.contains(keyword)) {
        return rule;
      }

      // 2) 해외승인 접두어(prefix) 매칭
      //    잘린 사용처(예: "G", "GE", "ANT")가 등록 키워드의 시작 부분과 일치하면 매칭
      if (isOverseas &&
          trimmedMerchant.isNotEmpty &&
          keyword.startsWith(trimmedMerchant)) {
        return rule;
      }
    }
    return null;
  }

  /// 자동 분류 로직: 매핑규칙(해외 prefix 포함) > 식대(점심시간) > 기타
  /// 반환: (category, detail, isMealSuggested)
  static ClassificationResult classify({
    required DateTime dateTime,
    required String merchant,
    required String rawMessage,
    required List<MappingRule> mappingRules,
    bool isOverseas = false,
  }) {
    // 1) 매핑 규칙이 우선 적용 (특정 사용처는 항상 지정된 값으로)
    final rule = findMappingRule(
      merchant,
      rawMessage,
      mappingRules,
      isOverseas: isOverseas,
    );
    if (rule != null) {
      return ClassificationResult(
        category: rule.category,
        detail: rule.detail,
        isMealSuggested: false,
        matchedKeyword: rule.keyword,
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
  final String? matchedKeyword; // 해외 prefix 매칭 등으로 확정된 정식 사용처명

  ClassificationResult({
    required this.category,
    required this.detail,
    required this.isMealSuggested,
    this.matchedKeyword,
  });
}
