import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import 'shortcut_guide_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              icon: Icons.groups,
              title: '팀원(공동사용자) 관리',
              subtitle: '식대 결제 시 선택할 수 있는 인원 목록입니다',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamMembersScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.rule,
              title: '자동 매핑 규칙',
              subtitle: '특정 사용처(GENSPARK.AI 등)의 상세내용/계정과목 자동지정 규칙',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MappingRulesScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.phone_iphone,
              title: '아이폰 단축어 연동 가이드',
              subtitle: '카드 문자를 자동으로 앱에 전달받는 방법',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShortcutGuideScreen()),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEF0FA)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade400),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Smart SMS Ledger · 법인카드 정산 가계부\n모든 데이터는 이 기기에만 저장됩니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF0FA)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// 팀원 관리 화면
// ------------------------------------------------------------------

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await context.read<TransactionProvider>().addTeamMember(name);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<TransactionProvider>().teamMembers;

    return Scaffold(
      appBar: AppBar(title: const Text('팀원 관리')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '이름 입력 (예: 김현호)',
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        '등록된 팀원이 없습니다.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final name = members[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                name.characters.first,
                                style: const TextStyle(color: AppTheme.primary),
                              ),
                            ),
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.danger,
                              ),
                              onPressed: () {
                                context
                                    .read<TransactionProvider>()
                                    .removeTeamMember(name);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// 자동 매핑 규칙 관리 화면
// ------------------------------------------------------------------

class MappingRulesScreen extends StatelessWidget {
  const MappingRulesScreen({super.key});

  void _showEditDialog(BuildContext context, {int? index, MappingRule? rule}) {
    final keywordController = TextEditingController(text: rule?.keyword ?? '');
    final detailController = TextEditingController(text: rule?.detail ?? '');
    String category = rule?.category ?? '기타';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(index == null ? '규칙 추가' : '규칙 수정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '사용처 키워드',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keywordController,
                      decoration: const InputDecoration(
                        hintText: '예: GENSPARK.AI',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '상세내용 자동입력',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: detailController,
                      decoration: const InputDecoration(
                        hintText: '예: AI 서비스 구독료',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '계정과목',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kCategories.map((c) {
                        final selected = c == category;
                        return ChoiceChip(
                          label: Text(
                            c,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => category = c),
                          selectedColor: AppTheme.categoryColor(c),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final keyword = keywordController.text.trim();
                    if (keyword.isEmpty) return;
                    final newRule = MappingRule(
                      keyword: keyword,
                      detail: detailController.text.trim(),
                      category: category,
                    );
                    final provider = ctx.read<TransactionProvider>();
                    if (index == null) {
                      provider.addMappingRule(newRule);
                    } else {
                      provider.updateMappingRuleAt(index, newRule);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = context.watch<TransactionProvider>().mappingRules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('자동 매핑 규칙'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: rules.isEmpty
            ? Center(
                child: Text(
                  '등록된 규칙이 없습니다.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.categoryColor(
                            rule.category,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppTheme.categoryIcon(rule.category),
                          color: AppTheme.categoryColor(rule.category),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        rule.keyword,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${rule.detail} · ${rule.category}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditDialog(
                              context,
                              index: index,
                              rule: rule,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.danger,
                              size: 20,
                            ),
                            onPressed: () {
                              context
                                  .read<TransactionProvider>()
                                  .removeMappingRuleAt(index);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
