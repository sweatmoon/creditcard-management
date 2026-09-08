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
