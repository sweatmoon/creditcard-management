# ---------- 1단계: Flutter 웹 빌드 ----------
FROM ghcr.io/cirruslabs/flutter:3.35.4 AS build

WORKDIR /app

# 의존성 캐시 활용을 위해 pubspec 먼저 복사
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 나머지 소스 복사 후 웹 릴리즈 빌드
COPY . .
RUN flutter build web --release

# ---------- 2단계: API 서버 + 정적 파일 서빙 (Node.js) ----------
FROM node:20-alpine AS runtime

WORKDIR /app

# 서버 의존성 설치
COPY server/package.json ./
RUN npm install --omit=dev

# 서버 코드 복사 (server/ 내 모든 .js 파일 - 신규 파일 추가 시 매번 수정할 필요 없도록)
COPY server/*.js ./

# Flutter 웹 빌드 결과물을 정적 파일 디렉터리로 복사
COPY --from=build /app/build/web ./public

# Railway가 주입하는 $PORT를 사용 (로컬 기본값 8080)
ENV PORT=8080
ENV STATIC_DIR=/app/public
EXPOSE 8080

CMD ["node", "index.js"]
