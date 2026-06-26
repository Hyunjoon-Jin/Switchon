# Netlify 웹 배포 안내

이미 준비된 것 (자동 완료):
- 웹 호환 코드 + `netlify.toml`(빌드 명령/배포 폴더) + `netlify_build.sh`
- Netlify 사이트: **switchon-diet** → https://switchon-diet.netlify.app
- 관리 화면: https://app.netlify.com/projects/switchon-diet
- 환경변수 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 입력 완료

## 마지막 단계 — 깃허브 저장소 연결 (브라우저, 2~3분)
GitHub ↔ Netlify 연결 승인은 본인만 할 수 있어요.

1. https://app.netlify.com/projects/switchon-diet 접속 (Netlify 로그인)
2. **Site configuration → Build & deploy → Continuous deployment** 이동
3. **Link repository**(저장소 연결) 클릭 → **GitHub** 선택 → 권한 승인(Authorize)
4. 저장소 **`hyunjoon-jin/switchon`** 선택
5. **Branch(브랜치)**를 **`claude/switchon-diet-app-brief-14o0ha`** 로 지정
   - 빌드 명령/배포 폴더는 `netlify.toml`에서 자동으로 채워져요
   - (필요 시) Build command: `bash netlify_build.sh`, Publish directory: `build/web`
6. **Deploy(배포)** 클릭

첫 빌드는 Flutter 다운로드 때문에 **5~10분**쯤 걸려요. 끝나면
**https://switchon-diet.netlify.app** 에서 앱이 열려요. (폰 브라우저로 바로 접속 가능)

## 빌드가 실패하면?
관리 화면의 **Deploys → 실패한 배포 → Deploy log** 를 열어 마지막 빨간 오류를
복사해 주세요. 원인을 바로 잡아드릴게요. (Flutter 웹 빌드는 처음 한두 번 조정이
필요할 수 있어요.)

## 참고
- 웹에서는 푸시/로컬 알림이 동작하지 않아요(코드가 자동으로 건너뜀). 나머지 기능은 정상.
- 코드를 그 브랜치에 새로 푸시하면 Netlify가 자동으로 다시 배포해요.
