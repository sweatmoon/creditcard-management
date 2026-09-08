import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 아이폰 단축어(Shortcuts) 자동화 설정 가이드
/// 웹 앱은 SMS를 직접 읽을 수 없으므로, 단축어의 "메시지 받을 때" 오토메이션 +
/// "URL 열기" 액션으로 문자 내용을 이 웹앱의 /add?text=... 파라미터로 전달받는 방식 안내
class ShortcutGuideScreen extends StatelessWidget {
  const ShortcutGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('아이폰 단축어 연동 가이드')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '아이폰 "단축어" 앱의 자동화 기능을 이용하면, 법인카드 승인 문자가 올 때마다\n'
                      '자동으로 이 앱이 열리며 내용이 미리 채워집니다.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _step(
              number: '1',
              title: '단축어 앱 실행 → 오토메이션',
              desc:
                  '아이폰의 "단축어" 앱을 열고 하단의 "오토메이션" 탭으로 이동한 뒤\n'
                  '우측 상단 "+" 버튼을 눌러 "개인 자동화 생성"을 선택하세요.',
            ),
            _step(
              number: '2',
              title: '"메시지" 조건 선택',
              desc:
                  '조건 목록에서 "메시지"를 선택하고,\n'
                  '"발신자"에 법인카드 승인 문자가 오는 전화번호(예: 1599-8800)를 입력하세요.',
            ),
            _step(
              number: '3',
              title: '동작 추가: "URL 열기"',
              desc:
                  '동작 추가에서 "URL 열기"를 검색해 추가한 뒤,\n'
                  'URL 입력란에 아래 주소를 붙여넣고 텍스트 부분을\n'
                  '"단축어 입력" 변수(메시지 내용)로 바꿔주세요.',
            ),
            Container(
              margin: const EdgeInsets.only(left: 46, bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D29),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SelectableText(
                '현재 앱 주소/add?text=[메시지 내용]',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
              ),
            ),
            _step(
              number: '4',
              title: '"바로 실행" 설정',
              desc:
                  '마지막에 "실행 전 확인"을 꺼서 "바로 실행"으로 설정하면\n'
                  '문자가 오는 즉시 확인창 없이 자동으로 앱이 열립니다.',
            ),
            _step(
              number: '5',
              title: '앱에서 확인 후 저장',
              desc:
                  '앱이 열리면 문자 내용이 자동으로 분석되어\n'
                  '사용처/금액/계정과목이 미리 채워집니다. 확인 후 저장만 누르면 끝!',
              isLast: true,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '단축어 자동화는 iOS 시스템 기능으로, 위 설정은 사용자가 아이폰에서\n'
                      '직접 1회 진행해야 합니다. 이후에는 완전 자동으로 동작합니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.warning.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _step({
    required String number,
    required String title,
    required String desc,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE0E2EF),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
