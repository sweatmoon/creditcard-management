/// 백엔드 API(Railway 서버) 연결 설정
///
/// 웹에서는 Flutter Web과 API 서버(Node.js/Express)가 "같은 오리진"에서
/// 함께 서빙되므로(server/index.js가 정적파일+API를 모두 서빙), 별도의
/// baseUrl 없이 상대경로('/api/...')로 호출하면 PC 웹/모바일 웹 어디서든
/// 동일한 Railway Postgres DB에 접근하게 되어 자동으로 동기화된다.
///
/// 만약 Android 네이티브 APK 등 별도 오리진에서 이 앱을 구동해야 한다면,
/// 아래 baseUrl에 배포된 Railway 도메인(예: https://xxx.up.railway.app)을
/// 지정하면 된다.
class ApiConfig {
  static const String baseUrl = '';
}
