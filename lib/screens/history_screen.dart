import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/export_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import 'transaction_detail_screen.dart';

/// 전체 거래내역 조회 + 필터 + 엑셀 정산 리포트 내보내기
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _categoryFilter;
  bool _exporting = false;

  // 표 컬럼 폭 (헤더/데이터 행 공통으로 사용)
  static const double _colDateWidth = 92;
  static const double _colMerchantWidth = 130;
  static const double _colCategoryWidth = 96;
  static const double _colDetailWidth = 140;
  static const double _colCoUsersWidth = 100;
  static const double _colAmountWidth = 90;
  static double get _tableWidth =>
      _colDateWidth +
      _colMerchantWidth +
      _colCategoryWidth +
      _colDetailWidth +
      _colCoUsersWidth +
      _colAmountWidth +
      40; // padding 여유

  List<CardTransaction> _filtered(TransactionProvider provider) {
    var list = provider.transactionsForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    if (_categoryFilter != null) {
      list = list.where((t) => t.category == _categoryFilter).toList();
    }
    // 날짜/시간 오름차순(과거 -> 최근) 정렬
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  /// 셀 값을 클립보드에 복사하고 스낵바로 안내
  void _copyCell(String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$value" 복사됨'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _export(List<CardTransaction> list) async {
    if (list.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내보낼 내역이 없습니다.')));
      return;
    }
    setState(() => _exporting = true);
    try {
      final monthLabel = DateFormat('yyyyMM').format(_selectedMonth);
      await ExportService.exportAndSave(
        list,
        fileName: '법인카드_정산내역_$monthLabel',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('엑셀 파일이 다운로드되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickMonth() async {
    int year = _selectedMonth.year;
    int month = _selectedMonth.month;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setSheetState(() {
                            if (month == 1) {
                              month = 12;
                              year -= 1;
                            } else {
                              month -= 1;
                            }
                          });
                        },
                      ),
                      Text(
                        '$year년 $month월',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setSheetState(() {
                            if (month == 12) {
                              month = 1;
                              year += 1;
                            } else {
                              month += 1;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedMonth = DateTime(year, month));
                        Navigator.pop(ctx);
                      },
                      child: const Text('선택'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final list = _filtered(provider);
    final totalByCurrency = <String, double>{};
    for (final t in list) {
      totalByCurrency[t.currency] =
          (totalByCurrency[t.currency] ?? 0) + t.amount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내역 / 정산')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickMonth,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EF)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('yyyy년 M월').format(_selectedMonth),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _exporting ? null : () => _export(list),
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share, size: 18),
                    label: const Text('엑셀'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _filterChip('전체', null),
                  ...kCategories.map((c) => _filterChip(c, c)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${list.length}건',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 4,
                    children: totalByCurrency.entries.map((e) {
                      return Text(
                        AmountFormatter.format(e.value, e.key),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '셀 탭: 복사 · 길게 누르기: 상세보기/수정',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        '해당 조건의 내역이 없습니다.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _tableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTableHeader(),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  itemBuilder: (context, index) {
                                    final tx = list[index];
                                    return _buildTableRow(tx);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 표 형태 목록의 헤더 행 (날짜/시간 · 사용처 · 계정과목 · 공동사용자 · 금액)
  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _colDateWidth,
            child: const Text('날짜/시간', style: style),
          ),
          SizedBox(
            width: _colMerchantWidth,
            child: const Text('사용처', style: style),
          ),
          SizedBox(
            width: _colCategoryWidth,
            child: const Text(
              '계정과목',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _colDetailWidth,
            child: const Text(
              '상세내용',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _colCoUsersWidth,
            child: const Text(
              '공동사용자',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _colAmountWidth,
            child: const Text('금액', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  /// 기능(복사/상세보기) 설명이 통합된 표 셀 위젯 - 탭은 클립보드 복사, 길게 누르면(long press) 상세로 이동
  Widget _cell({
    required double width,
    required String displayText,
    required String copyText,
    required VoidCallback onOpenDetail,
    TextStyle? style,
    TextAlign textAlign = TextAlign.left,
    Widget? child,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _copyCell(copyText),
        onLongPress: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child:
              child ??
              Text(
                displayText,
                textAlign: textAlign,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
        ),
      ),
    );
  }

  /// 표 형태 목록의 데이터 행 1건
  /// 각 셀 탭: 해당 값 클립보드 복사 / 길게 누르면: 상세화면 이동
  Widget _buildTableRow(CardTransaction tx) {
    final color = AppTheme.categoryColor(tx.category);
    final coUsersText = tx.coUsers.isEmpty ? '-' : tx.coUsers.join(', ');
    final detailText = tx.detail.isEmpty ? '-' : tx.detail;
    void openDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(transaction: tx),
        ),
      );
    }

    final dateText = DateFormat('MM/dd HH:mm').format(tx.dateTime);
    final amountText = AmountFormatter.format(tx.amount, tx.currency);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell(
            width: _colDateWidth,
            displayText: dateText,
            copyText: dateText,
            onOpenDetail: openDetail,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          _cell(
            width: _colMerchantWidth,
            displayText: tx.merchant,
            copyText: tx.merchant,
            onOpenDetail: openDetail,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          _cell(
            width: _colCategoryWidth,
            displayText: tx.category,
            copyText: tx.category,
            onOpenDetail: openDetail,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tx.category,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _cell(
            width: _colDetailWidth,
            displayText: detailText,
            copyText: detailText,
            onOpenDetail: openDetail,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
          _cell(
            width: _colCoUsersWidth,
            displayText: coUsersText,
            copyText: coUsersText,
            onOpenDetail: openDetail,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
          _cell(
            width: _colAmountWidth,
            displayText: amountText,
            copyText: amountText,
            onOpenDetail: openDetail,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        selected: selected,
        onSelected: (_) => setState(() => _categoryFilter = value),
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
