#!/usr/bin/env bash
# Netlify 클라우드 빌드 스크립트 — Flutter Web 빌드.
# 필요한 환경변수(Netlify Site settings → Environment variables):
#   SUPABASE_URL, SUPABASE_ANON_KEY
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"

echo "▶ Flutter SDK 내려받기 ($FLUTTER_VERSION)…"
if [ ! -d "flutter" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git
fi
export PATH="$PWD/flutter/bin:$PATH"

flutter --version
flutter config --enable-web

echo "▶ 웹 플랫폼 폴더 생성…"
flutter create . --platforms=web
# 커스텀 파일 적용 (flutter create 가 만든 것 덮어쓰기)
cp tools/index.html web/index.html
cp tools/manifest.json web/manifest.json

echo "▶ 의존성 설치…"
flutter pub get

echo "▶ 웹 빌드 (release)…"
# --pwa-strategy=none: Service Worker 를 생성하지 않아 옛 빌드가 캐시되어
# 새 배포가 안 보이는 문제를 막는다(온라인 전용 앱이라 오프라인 캐시 불필요).
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

# 과거에 설치된 Flutter SW 를 제거하는 킬-스위치 SW 를 같은 경로로 배포.
cp tools/flutter_service_worker.js build/web/flutter_service_worker.js

# 캐시/보안 헤더 + SPA 리다이렉트 — 직접 배포에서도 반드시 적용되도록
# 퍼블리시 폴더(build/web)에 _headers/_redirects 를 함께 배포한다.
cp tools/_headers build/web/_headers
cp tools/_redirects build/web/_redirects

echo "✅ 빌드 완료 → build/web"
