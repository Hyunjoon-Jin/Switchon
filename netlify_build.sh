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

echo "▶ 웹 빌드 (release, html renderer — 모바일 최적화)…"
flutter build web --release \
  --web-renderer html \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

echo "✅ 빌드 완료 → build/web"
