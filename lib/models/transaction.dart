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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'currency': currency,
      'category': category,
      'detail': detail,
      'coUsers': coUsers,
      'dateTime': dateTime,
      'cardHolder': cardHolder,
      'rawMessage': rawMessage,
      'createdAt': createdAt,
    };
  }

  factory CardTransaction.fromMap(Map<dynamic, dynamic> map) {
    return CardTransaction(
      id: map['id'] as String? ?? '',
      merchant: map['merchant'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'KRW',
      category: map['category'] as String? ?? '기타',
      detail: map['detail'] as String? ?? '',
      coUsers:
          (map['coUsers'] as List?)?.map((e) => e.toString()).toList() ??
          <String>[],
      dateTime: map['dateTime'] as DateTime? ?? DateTime.now(),
      cardHolder: map['cardHolder'] as String?,
      rawMessage: map['rawMessage'] as String? ?? '',
      createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
    );
  }
}

/// 특정 사용처 자동 매핑 규칙
class MappingRule {
  final String keyword; // 사용처에 포함될 키워드
  final String detail; // 자동 지정될 상세내용
  final String category; // 자동 지정될 계정과목

  MappingRule({
    required this.keyword,
    required this.detail,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {'keyword': keyword, 'detail': detail, 'category': category};
  }

  factory MappingRule.fromMap(Map<dynamic, dynamic> map) {
    return MappingRule(
      keyword: map['keyword'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      category: map['category'] as String? ?? '기타',
    );
  }
}
