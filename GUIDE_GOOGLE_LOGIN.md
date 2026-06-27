# 구글 로그인 연결 가이드

코드(버튼·OAuth 호출)는 이미 추가됨. 아래 설정만 하면 작동해요.
복붙용 값:
- Supabase 콜백 URL: `https://fzaujefqucfbapohbkpi.supabase.co/auth/v1/callback`
- 앱 주소: `https://switchondiet.netlify.app`

---

## A. 구글 클라우드 콘솔 (OAuth 앱 만들기)
https://console.cloud.google.com 접속 (구글 로그인)

1. **프로젝트 생성**: 상단 프로젝트 선택 → "새 프로젝트" → 이름(예: switchon) → 만들기 → 그 프로젝트 선택
2. 좌측 메뉴 **API 및 서비스 → OAuth 동의 화면**
   - User Type: **외부(External)** → 만들기
   - 앱 이름 `스위치온`, 사용자 지원 이메일(본인), 개발자 연락처 이메일(본인) → 저장 후 계속
   - 범위(Scopes): 건드리지 말고 저장 후 계속
   - 테스트 사용자: **본인 구글 이메일 추가** → 저장 후 계속
3. **API 및 서비스 → 사용자 인증 정보** → 상단 "사용자 인증 정보 만들기" → **OAuth 클라이언트 ID**
   - 애플리케이션 유형: **웹 애플리케이션**
   - **승인된 JavaScript 원본**에 추가: `https://switchondiet.netlify.app`
   - **승인된 리디렉션 URI**에 추가: `https://fzaujefqucfbapohbkpi.supabase.co/auth/v1/callback`
   - 만들기 → 뜨는 **클라이언트 ID**와 **클라이언트 보안 비밀번호(Secret)** 복사

---

## B. Supabase (구글 공급자 켜기)
https://supabase.com/dashboard/project/fzaujefqucfbapohbkpi

1. **Authentication → Sign In / Providers → Google** → 토글 **Enable**
2. 위에서 복사한 **Client ID**, **Client Secret** 붙여넣기 → **Save**
3. **Authentication → URL Configuration**
   - **Site URL**: `https://switchondiet.netlify.app`
   - **Redirect URLs** 에 추가: `https://switchondiet.netlify.app/**`
   - Save

---

## C. 테스트
1. 앱 `https://switchondiet.netlify.app` 새로고침
2. **"Google로 계속하기"** 탭 → 구글 계정 선택 → 앱으로 돌아오면 로그인 완료 🎉

## 참고
- OAuth 동의 화면이 "테스트 중" 상태면 **테스트 사용자로 추가한 이메일만** 로그인돼요.
  (본인만 쓸 거면 그대로 OK. 누구나 쓰게 하려면 동의 화면을 "게시"하세요 — 기본 범위라 별도 심사 거의 없음.)
- 막히면 그 화면을 캡처해 주세요.
