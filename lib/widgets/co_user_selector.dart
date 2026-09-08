import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/theme.dart';

/// 공동사용자 선택 위젯
/// - 팀원 리스트에서 체크박스로 다중 선택
/// - 리스트에 없는 인원은 직접 입력으로 추가 (선택 시 자동으로 팀원 리스트에도 등록됨)
class CoUserSelector extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const CoUserSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<CoUserSelector> createState() => _CoUserSelectorState();
}

class _CoUserSelectorState extends State<CoUserSelector> {
  final _customController = TextEditingController();
  // 이번 거래에서 "직접 입력"으로 추가된 임시 인원 (팀원 리스트에 없어도 표시)
  final List<String> _customAdded = [];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    final list = List<String>.from(widget.selected);
    if (list.contains(name)) {
      list.remove(name);
    } else {
      list.add(name);
    }
    widget.onChanged(list);
  }

  void _addCustom() {
    final name = _customController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (!_customAdded.contains(name)) {
        _customAdded.add(name);
      }
      _customController.clear();
    });
    final list = List<String>.from(widget.selected);
    if (!list.contains(name)) {
      list.add(name);
    }
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final teamMembers = provider.teamMembers;

    // 팀원 리스트 + 이번에 직접 입력한 인원 합쳐서 보여줌 (중복 제거)
    final allDisplayNames = <String>{...teamMembers, ..._customAdded}.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allDisplayNames.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '등록된 팀원이 없습니다. 아래에서 이름을 직접 추가해주세요.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allDisplayNames.map((name) {
                final isSelected = widget.selected.contains(name);
                return FilterChip(
                  label: Text(name),
                  selected: isSelected,
                  onSelected: (_) => _toggle(name),
                  selectedColor: AppTheme.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: const InputDecoration(
                    hintText: '리스트에 없는 인원 직접 입력',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCustom(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCustom,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (widget.selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '선택됨: ${widget.selected.join(', ')}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
