import 'package:intl/intl.dart';

/// 통화별 금액 포맷팅 헬퍼
/// KRW는 정수+원, USD 등 외화는 소수점 2자리+통화기호로 표시
class AmountFormatter {
  static final _krwFormat = NumberFormat('#,###');
  static final _usdFormat = NumberFormat('#,##0.00');

  /// 취소 문자(수수료 차감 취소 등)는 amount가 음수로 저장되므로, 부호가
  /// 통화기호 앞에 오도록 명시적으로 처리한다. (예: "-$14.00", "-14,000원")
  static String format(double amount, String currency) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final sign = isNegative ? '-' : '';
    if (currency == 'KRW') {
      return '$sign${_krwFormat.format(absAmount)}원';
    }
    final symbol = _currencySymbol(currency);
    return '$sign$symbol${_usdFormat.format(absAmount)}';
  }

  static String _currencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return r'$';
      case 'JPY':
        return '¥';
      case 'EUR':
        return '€';
      default:
        return '$currency ';
    }
  }
}
