// 킬-스위치 Service Worker (v3).
// 과거 빌드에서 설치된 Flutter 의 캐싱 SW 가 옛 앱을 계속 띄우는 문제를 해결한다.
// 브라우저가 SW 업데이트를 확인할 때 이 파일(이전과 다른 내용)을 받아 새 SW 로
// 교체하고, 활성화되면 (1) 모든 캐시를 비우고 (2) 자신을 등록 해제한 뒤
// (3) 열려 있는 탭을 "캐시 우회"로 새로고침한다. 결과적으로 SW 가 사라지고
// 옛 HTTP 캐시까지 무시되어 항상 최신 빌드가 로드된다.
// (앱은 --pwa-strategy=none 으로 빌드되어 더 이상 SW 를 등록하지 않는다.)

self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    try {
      var keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    } catch (e) {}
    try { await self.clients.claim(); } catch (e) {}
    var wins = [];
    try { wins = await self.clients.matchAll({ type: 'window' }); } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
    // 캐시 우회 새로고침: 옛 HTTP 캐시(index.html/main.dart.js)까지 무시하도록
    // 캐시-버스팅 쿼리를 붙여 네비게이션한다. (일회성 — SW 는 이후 사라진다.)
    wins.forEach(function (c) {
      try {
        var u = new URL(c.url);
        u.searchParams.set('swpurge', '' + Date.now());
        c.navigate(u.href);
      } catch (e) {
        try { c.navigate(c.url); } catch (e2) {}
      }
    });
  })());
});

// 이 SW 가 클라이언트를 제어하는 짧은 순간에도, 네비게이션(HTML) 요청은
// 캐시를 완전히 무시하고 네트워크에서 새로 받아 옛 앱 셸이 다시 뜨지 않게 한다.
self.addEventListener('fetch', function (event) {
  var req = event.request;
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(new Request(req.url, { cache: 'reload' })).catch(function () {
        return fetch(req);
      })
    );
  }
  // 그 외 요청은 가로채지 않는다(브라우저 기본 처리 → 네트워크).
});
