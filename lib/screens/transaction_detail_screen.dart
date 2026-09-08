import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/co_user_selector.dart';

/// 거래 내역 상세보기 / 수정 화면
/// 사용처가 SMS 바이트 제한으로 잘려나오는 경우가 있어 여기서 직접 수정 가능
class TransactionDetailScreen extends StatefulWidget {
  final CardTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _detailController;
  late String _category;
  late DateTime _dateTime;
  late List<String> _coUsers;
  late String _currency;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _merchantController = TextEditingController(text: tx.merchant);
    _currency = tx.currency;
    _amountController = TextEditingController(
      text: _currency == 'KRW'
          ? tx.amount.toStringAsFixed(0)
          : tx.amount.toStringAsFixed(2),
    );
    _detailController = TextEditingController(text: tx.detail);
    _category = tx.category;
    _dateTime = tx.dateTime;
    _coUsers = List<String>.from(tx.coUsers);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  /// 수정 모드 진입/취소 토글.
  /// 취소(X) 시에는 편집 중이던 값을 버리고 원본(widget.transaction) 값으로
  /// 컨트롤러/상태를 되돌린다. (이전에는 컨트롤러 값이 그대로 남아있어
  /// 보기 모드로 돌아가도 마치 저장된 것처럼 잘못된 값이 표시되는 문제가 있었음)
  void _toggleEditing() {
    if (_editing) {
      // 편집 취소: 원본 값으로 복원
      final tx = widget.transaction;
      _merchantController.text = tx.merchant;
      _currency = tx.currency;
      _amountController.text = _currency == 'KRW'
          ? tx.amount.toStringAsFixed(0)
          : tx.amount.toStringAsFixed(2);
      _detailController.text = tx.detail;
      _category = tx.category;
      _dateTime = tx.dateTime;
      _coUsers = List<String>.from(tx.coUsers);
    }
    setState(() => _editing = !_editing);
  }

  Future<void> _save() async {
    final merchant = _merchantController.text.trim();
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (merchant.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용처와 금액을 올바르게 입력해주세요.')));
      return;
    }

    final updated = widget.transaction.copyWith(
      merchant: merchant,
      amount: amount,
      currency: _currency,
      category: _category,
      detail: _detailController.text.trim(),
      coUsers: _coUsers,
      dateTime: _dateTime,
    );

    await context.read<TransactionProvider>().updateTransaction(updated);
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 거래 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      await context.read<TransactionProvider>().deleteTransaction(
        widget.transaction.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 상세'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: _toggleEditing,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_editing) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.categoryColor(
                      _category,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            AppTheme.categoryIcon(_category),
                            color: AppTheme.categoryColor(_category),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _category,
                            style: TextStyle(
                              color: AppTheme.categoryColor(_category),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _merchantController.text,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AmountFormatter.format(
                          double.tryParse(_amountController.text) ?? 0,
                          _currency,
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currency != 'KRW') ...[
                        const SizedBox(height: 4),
                        Text(
                          '해외 결제 ($_currency, 환전 없이 원문 금액 그대로 저장됨)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        DateFormat(
                          'yyyy-MM-dd (E) HH:mm',
                          'ko_KR',
                        ).format(_dateTime),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_detailController.text.isNotEmpty)
                  _infoRow('상세내용', _detailController.text),
                if (_coUsers.isNotEmpty) _infoRow('공동사용자', _coUsers.join(', ')),
                if (widget.transaction.cardHolder != null)
                  _infoRow('카드명의자', widget.transaction.cardHolder!),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    '원본 문자 보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.transaction.rawMessage,
                        style: const TextStyle(fontSize: 12.5, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _editField('사용처', _merchantController),
                const SizedBox(height: 12),
                _editField(
                  _currency == 'KRW' ? '금액 (원)' : '금액 ($_currency)',
                  _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _editField('상세내용', _detailController),
                const SizedBox(height: 12),
                const Text(
                  '거래 일시',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateTime,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date == null) return;
                    if (!mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_dateTime),
                    );
                    if (time == null) return;
                    setState(() {
                      _dateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F1F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat(
                        'yyyy-MM-dd (E) HH:mm',
                        'ko_KR',
                      ).format(_dateTime),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '계정과목',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kCategories.map((c) {
                    final selected = c == _category;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = c),
                      selectedColor: AppTheme.categoryColor(c),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '공동사용자',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                CoUserSelector(
                  selected: _coUsers,
                  onChanged: (list) => setState(() => _coUsers = list),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('저장'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(controller: controller, keyboardType: keyboardType),
      ],
    );
  }
}
