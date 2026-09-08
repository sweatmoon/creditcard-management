import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 아이폰 단축어(Shortcuts) 자동화 설정 가이드
///
/// "URL의 콘텐츠 가져오기(Get Contents of URL)" POST 액션으로 문자 원문을
/// 서버(/api/sms/ingest)에 직접 전송하는 방식. Safari/앱 화면이 전혀 뜨지 않고
/// 잠금 상태에서도 완전히 백그라운드로 동작한다.
/// - 서버가 파싱에 확신이 있으면 즉시 거래내역에 자동 저장
/// - 애매한 경우(식대 추정 등)만 "검토 대기"에 쌓여 앱에서 나중에 확인
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
                      '화면이 켜지지 않고 완전히 백그라운드로 서버에 전송되어 자동 저장됩니다.\n'
                      '(파싱이 애매한 경우만 앱의 "검토 대기"에 남습니다)',
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
              title: '동작 추가: "URL의 콘텐츠 가져오기"',
              desc:
                  '동작 추가에서 "URL의 콘텐츠 가져오기(Get Contents of URL)"를 검색해 추가하세요.\n'
                  'Safari를 여는 "URL 열기"가 아니라, 이 동작이어야 화면이 뜨지 않습니다.',
            ),
            _step(
              number: '4',
              title: 'URL / 방법 / 요청 본문(JSON) 설정',
              desc:
                  '동작을 눌러 아래 4가지를 설정하세요:\n'
                  '① URL: 아래 주소 입력\n'
                  '② 방법: POST\n'
                  '③ 요청 본문: JSON 선택\n'
                  '④ JSON에 "text" 필드를 추가하고 값은 "단축어 입력"(메시지 내용) 변수로 지정',
            ),
            Container(
              margin: const EdgeInsets.only(left: 46, bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D29),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SelectableText(
                '현재 앱 주소/api/sms/ingest\n\n'
                'JSON 요청 본문:\n'
                '{ "text": [단축어 입력] }',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
            ),
            _step(
              number: '5',
              title: '"바로 실행" 설정',
              desc:
                  '마지막에 "실행 전 확인"을 꺼서 "바로 실행"으로 설정하면\n'
                  '문자가 오는 즉시, 화면이 켜지지 않고 조용히 서버로 전송됩니다.',
            ),
            _step(
              number: '6',
              title: '앱에서는 "검토 대기"만 확인',
              desc:
                  '대부분의 경우 자동으로 저장까지 완료됩니다.\n'
                  '식대로 추정되어 공동사용자 확인이 필요하거나, 인식하지 못한 문자만\n'
                  '홈 화면의 "검토 대기" 알림에 표시되니 그때만 앱을 열어 확인하세요.',
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
                      '직접 1회 진행해야 합니다. 이후에는 완전 자동(백그라운드)으로 동작합니다.\n'
                      '단, iOS 정책상 저전력 모드 등에서는 자동화 실행이 약간 지연될 수 있습니다.',
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
