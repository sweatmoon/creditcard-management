import 'package:intl/intl.dart';

/// 통화별 금액 포맷팅 헬퍼
/// KRW는 정수+원, USD 등 외화는 소수점 2자리+통화기호로 표시
class AmountFormatter {
  static final _krwFormat = NumberFormat('#,###');
  static final _usdFormat = NumberFormat('#,##0.00');

  static String format(double amount, String currency) {
    if (currency == 'KRW') {
      return '${_krwFormat.format(amount)}원';
    }
    final symbol = _currencySymbol(currency);
    return '$symbol${_usdFormat.format(amount)}';
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
