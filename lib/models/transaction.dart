/// 법인카드 사용 내역 1건을 표현하는 모델
class CardTransaction {
  final String id;
  final String merchant; // 사용처
  final double amount; // 금액 (해당 통화 기준 그대로, 환산하지 않음)
  final String currency; // 통화 (KRW, USD 등)
  final String category; // 계정과목
  final String detail; // 상세내용
  final List<String> coUsers; // 공동사용자 (식대인 경우 사용)
  final DateTime dateTime; // 거래 일시 (문자 기준)
  final String? cardHolder; // 카드 명의자 (참고용)
  final String rawMessage; // 원본 문자 전문
  final DateTime createdAt; // 앱에 등록된 시각

  CardTransaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.detail,
    required this.coUsers,
    required this.dateTime,
    required this.rawMessage,
    required this.createdAt,
    this.currency = 'KRW',
    this.cardHolder,
  });

  CardTransaction copyWith({
    String? merchant,
    double? amount,
    String? currency,
    String? category,
    String? detail,
    List<String>? coUsers,
    DateTime? dateTime,
    String? cardHolder,
    String? rawMessage,
  }) {
    return CardTransaction(
      id: id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      detail: detail ?? this.detail,
      coUsers: coUsers ?? this.coUsers,
      dateTime: dateTime ?? this.dateTime,
      cardHolder: cardHolder ?? this.cardHolder,
      rawMessage: rawMessage ?? this.rawMessage,
      createdAt: createdAt,
    );
  }

  /// API(JSON) 전송용 직렬화 - 날짜는 ISO8601 문자열로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'currency': currency,
      'category': category,
      'detail': detail,
      'coUsers': coUsers,
      'dateTime': dateTime.toIso8601String(),
      'cardHolder': cardHolder,
      'rawMessage': rawMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// API(JSON) 응답 역직렬화 - 날짜는 문자열(ISO8601)로 내려오므로 파싱
  factory CardTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v, DateTime fallback) {
      if (v == null) return fallback;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString())?.toLocal() ?? fallback;
    }

    return CardTransaction(
      id: json['id'] as String? ?? '',
      merchant: json['merchant'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'KRW',
      category: json['category'] as String? ?? '기타',
      detail: json['detail'] as String? ?? '',
      coUsers:
          (json['coUsers'] as List?)?.map((e) => e.toString()).toList() ??
          <String>[],
      dateTime: parseDate(json['dateTime'], DateTime.now()),
      cardHolder: json['cardHolder'] as String?,
      rawMessage: json['rawMessage'] as String? ?? '',
      createdAt: parseDate(json['createdAt'], DateTime.now()),
    );
  }
}

/// 특정 사용처 자동 매핑 규칙
class MappingRule {
  final int? id; // DB(Postgres)의 mapping_rules.id (서버에서 생성됨, 신규 생성 시 null)
  final String keyword; // 사용처에 포함될 키워드
  final String detail; // 자동 지정될 상세내용
  final String category; // 자동 지정될 계정과목

  MappingRule({
    this.id,
    required this.keyword,
    required this.detail,
    required this.category,
  });

  MappingRule copyWith({
    int? id,
    String? keyword,
    String? detail,
    String? category,
  }) {
    return MappingRule(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      detail: detail ?? this.detail,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'keyword': keyword,
      'detail': detail,
      'category': category,
    };
  }

  factory MappingRule.fromJson(Map<String, dynamic> json) {
    return MappingRule(
      id: json['id'] as int?,
      keyword: json['keyword'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      category: json['category'] as String? ?? '기타',
    );
  }
}

/// 단축어가 서버로 문자를 직접 전송(백그라운드)했을 때, 서버가 즉시 자동저장하지
/// 못하고(파싱 실패 또는 식대 추정으로 공동사용자 확인 필요) "검토 대기"로 쌓아둔 항목.
/// 앱에서 이 목록을 확인 후 승인(저장)하거나 거부(무시)할 수 있다.
class PendingSms {
  final int id;
  final String rawMessage;
  final String? merchant;
  final double? amount;
  final String currency;
  final DateTime? dateTime;
  final String? cardHolder;
  final String category;
  final String detail;
  final bool isMealSuggested;
  final bool parseSuccess; // false면 파싱 자체가 실패한 케이스(안내문자 등)
  final String? rejectReason;
  final String status; // pending / approved / rejected
  final DateTime createdAt;

  PendingSms({
    required this.id,
    required this.rawMessage,
    this.merchant,
    this.amount,
    this.currency = 'KRW',
    this.dateTime,
    this.cardHolder,
    this.category = '기타',
    this.detail = '',
    this.isMealSuggested = false,
    this.parseSuccess = false,
    this.rejectReason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory PendingSms.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return PendingSms(
      id: json['id'] as int,
      rawMessage: json['rawMessage'] as String? ?? '',
      merchant: json['merchant'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'KRW',
      dateTime: parseDate(json['dateTime']),
      cardHolder: json['cardHolder'] as String?,
      category: json['category'] as String? ?? '기타',
      detail: json['detail'] as String? ?? '',
      isMealSuggested: json['isMealSuggested'] as bool? ?? false,
      parseSuccess: json['parseSuccess'] as bool? ?? false,
      rejectReason: json['rejectReason'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt:
          parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
