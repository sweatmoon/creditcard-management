import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/co_user_selector.dart';

/// 문자메시지 붙여넣기 -> 파싱 -> 확인/수정 -> 저장 화면
class AddTransactionScreen extends StatefulWidget {
  final String? initialText;

  const AddTransactionScreen({super.key, this.initialText});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _textController = TextEditingController();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();

  ParsedSmsPreview? _preview;
  String _selectedCategory = '기타';
  DateTime? _selectedDateTime;
  List<String> _selectedCoUsers = [];
  bool _showMealPrompt = false;
  String _currency = 'KRW';

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _parse());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _parse() {
    final provider = context.read<TransactionProvider>();
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final preview = provider.parseSms(text);
    setState(() {
      _preview = preview;
      if (preview.success) {
        _merchantController.text = preview.merchant ?? '';
        _currency = preview.currency;
        _amountController.text = _currency == 'KRW'
            ? preview.amount.toStringAsFixed(0)
            : preview.amount.toStringAsFixed(2);
        _selectedCategory = preview.category;
        _selectedDateTime = preview.dateTime;
        _showMealPrompt = preview.isMealSuggested;
        _selectedCoUsers = [];
      }
    });

    if (!preview.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문자에서 금액을 인식하지 못했습니다. 아래 항목을 직접 입력해주세요.')),
      );
      setState(() {
        _selectedDateTime = DateTime.now();
      });
    }
  }

  Future<void> _save() async {
    final merchant = _merchantController.text.trim();
    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (merchant.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용처와 금액을 올바르게 입력해주세요.')));
      return;
    }

    if (_selectedCategory == '식대' && _selectedCoUsers.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('공동사용자 미선택'),
          content: const Text('식대는 공동사용자를 선택하는 것을 권장합니다.\n그래도 저장하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    final provider = context.read<TransactionProvider>();
    await provider.addTransaction(
      merchant: merchant,
      amount: amount,
      currency: _currency,
      category: _selectedCategory,
      detail: _preview?.detail ?? '',
      coUsers: _selectedCoUsers,
      dateTime: _selectedDateTime ?? DateTime.now(),
      cardHolder: _preview?.cardHolder,
      rawMessage: _textController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _preview != null;

    return Scaffold(
      appBar: AppBar(title: const Text('문자 추가')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '카드 승인 문자 붙여넣기',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      '[Web발신]\n취향마\n69,700원 승인\n제안 김현호 롯데법인7283\n일시불 05/15 11:50\n누적2,379,996원',
                  hintStyle: const TextStyle(color: Color(0xFFB0B3C0)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('자동 인식하기'),
                ),
              ),
              const SizedBox(height: 24),
              if (hasResult) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '내용 확인 / 수정',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                if (_preview?.isOverseas ?? false) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.public,
                          color: AppTheme.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _preview!.autoMatched
                                ? '해외승인 문자입니다. 사용처가 "${_preview!.merchant}"로 자동 매칭되었습니다.'
                                : '해외승인 문자입니다. 사용처 이름이 카드사에 의해 잘렸을 수 있어요. 확인해주세요.',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildField('사용처', _merchantController),
                const SizedBox(height: 12),
                _buildField(
                  _currency == 'KRW' ? '금액 (원)' : '금액 ($_currency)',
                  _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDateTimePicker(),
                const SizedBox(height: 12),
                _buildCategorySelector(),
                if (_showMealPrompt) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '점심시간(11:30~14:00) 결제라 "식대"로 자동 분류되었습니다.',
                            style: TextStyle(
                              color: AppTheme.warning.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_preview?.detail.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '상세내용 자동지정: ${_preview!.detail}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedCategory == '식대') ...[
                  const SizedBox(height: 16),
                  const Text(
                    '공동사용자',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  CoUserSelector(
                    selected: _selectedCoUsers,
                    onChanged: (list) {
                      setState(() => _selectedCoUsers = list);
                    },
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('저장하기'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
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

  Widget _buildDateTimePicker() {
    final dt = _selectedDateTime ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              initialDate: dt,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (date == null) return;
            if (!mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(dt),
            );
            if (time == null) return;
            setState(() {
              _selectedDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              _showMealPrompt = false;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd (E) HH:mm', 'ko_KR').format(dt)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '계정과목',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCategories.map((c) {
            final selected = c == _selectedCategory;
            return ChoiceChip(
              label: Text(c),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = c;
                  if (c != '식대') {
                    _showMealPrompt = false;
                  }
                });
              },
              selectedColor: AppTheme.categoryColor(c),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
