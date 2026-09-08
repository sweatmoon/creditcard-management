# ---------- 1단계: Flutter 웹 빌드 ----------
FROM ghcr.io/cirruslabs/flutter:3.35.4 AS build

WORKDIR /app

# 의존성 캐시 활용을 위해 pubspec 먼저 복사
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 나머지 소스 복사 후 웹 릴리즈 빌드
COPY . .
RUN flutter build web --release

# ---------- 2단계: 정적 파일 서빙 (nginx) ----------
FROM nginx:alpine AS runtime

# Railway는 매 배포마다 다른 $PORT를 주입하므로, nginx 설정에서 이를 반영해야 함
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
ENV PORT=8080

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["/bin/sh", "-c", "envsubst '$PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
