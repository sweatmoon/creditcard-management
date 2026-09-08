import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/co_user_selector.dart';

/// 단축어가 백그라운드로 보낸 문자 중, 서버가 즉시 자동저장하지 못하고
/// "검토 대기"로 쌓아둔 항목을 확인/승인/거부하는 화면.
///
/// 자동저장되지 않는 경우:
///  1) 파싱 실패 (카드 승인 문자 형식이 아니거나 안내성 문자)
///  2) 식대로 추정되었지만 공동사용자 확인이 필요한 경우
class PendingSmsScreen extends StatefulWidget {
  const PendingSmsScreen({super.key});

  @override
  State<PendingSmsScreen> createState() => _PendingSmsScreenState();
}

class _PendingSmsScreenState extends State<PendingSmsScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await context.read<TransactionProvider>().refreshPendingSms();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final list = provider.pendingSms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('검토 대기'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: list.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mark_email_read_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '검토 대기 중인 문자가 없습니다.\n단축어로 수신된 문자 중 확인이\n필요한 항목이 여기 표시됩니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _PendingCard(
                    pending: list[index],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final PendingSms pending;

  const _PendingCard({required this.pending});

  @override
  Widget build(BuildContext context) {
    final isFailed = !pending.parseSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFailed ? Icons.help_outline : Icons.restaurant,
                size: 18,
                color: isFailed ? AppTheme.warning : AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isFailed
                      ? (pending.rejectReason ?? '인식하지 못한 문자')
                      : '식대로 추정됨 · 공동사용자 확인 필요',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isFailed ? AppTheme.warning : AppTheme.primary,
                  ),
                ),
              ),
              Text(
                DateFormat('MM/dd HH:mm').format(pending.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              pending.rawMessage,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<TransactionProvider>().rejectPendingSms(
                      pending,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('무시했습니다.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('무시'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openReviewDialog(context),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(isFailed ? '직접 입력해 저장' : '확인 후 저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ReviewDialog(pending: pending),
    );
  }
}

/// 검토 대기 항목을 확인/수정 후 승인(저장)하는 다이얼로그
class _ReviewDialog extends StatefulWidget {
  final PendingSms pending;

  const _ReviewDialog({required this.pending});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late String _category;
  late DateTime _dateTime;
  List<String> _coUsers = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.pending;
    _merchantController = TextEditingController(text: p.merchant ?? '');
    _amountController = TextEditingController(
      text: p.amount != null ? p.amount!.toStringAsFixed(0) : '',
    );
    _category = p.category.isNotEmpty ? p.category : '기타';
    _dateTime = p.dateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final merchant = _merchantController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (merchant.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용처와 금액을 올바르게 입력해주세요.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<TransactionProvider>().approvePendingSms(
        widget.pending,
        merchant: merchant,
        amount: amount,
        currency: widget.pending.currency,
        category: _category,
        detail: widget.pending.detail,
        coUsers: _coUsers,
        dateTime: _dateTime,
        cardHolder: widget.pending.cardHolder,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('내용 확인'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '사용처',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            TextField(controller: _merchantController),
            const SizedBox(height: 12),
            Text(
              '금액 (${widget.pending.currency})',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '계정과목',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kCategories.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppTheme.categoryColor(c),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              '공동사용자',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            CoUserSelector(
              selected: _coUsers,
              onChanged: (list) => setState(() => _coUsers = list),
            ),
            const SizedBox(height: 10),
            Text(
              '거래일시: ${DateFormat('yyyy-MM-dd HH:mm').format(_dateTime)}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '금액 미리보기: ${AmountFormatter.format(double.tryParse(_amountController.text) ?? 0, widget.pending.currency)}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
