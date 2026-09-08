import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/transaction_provider.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await initializeDateFormatting('ko_KR', null);
  runApp(const MyApp());
}

/// 아이폰 단축어 "URL 열기" 연동을 위해, 웹 진입 시 URL의 ?text= 파라미터를 읽어옴
/// 예: https://내앱주소/?text=[Web발신]...문자내용...
String? _extractSharedTextFromUrl() {
  try {
    final uri = Uri.base;
    final text = uri.queryParameters['text'];
    if (text != null && text.trim().isNotEmpty) {
      return text;
    }
  } catch (_) {
    // 웹이 아닌 환경 등에서는 무시
  }
  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionProvider()..loadAll(),
      child: MaterialApp(
        title: 'Smart SMS Ledger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const RootScreen(),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  final _screens = const [HomeScreen(), HistoryScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    // 단축어를 통해 URL로 문자 텍스트가 전달된 경우, 자동으로 추가 화면을 띄움
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sharedText = _extractSharedTextFromUrl();
      if (sharedText != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(initialText: sharedText),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '내역'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
