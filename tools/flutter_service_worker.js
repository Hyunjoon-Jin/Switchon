// 킬-스위치 Service Worker.
// 과거 빌드에서 설치된 Flutter 의 캐싱 SW 가 옛 앱을 계속 띄우는 문제를 해결한다.
// 브라우저가 SW 업데이트를 확인할 때 이 파일(이전과 다른 내용)을 받아 새 SW 로
// 교체하고, 활성화되면 모든 캐시를 비우고 자신을 등록 해제한 뒤 열려 있는 탭을
// 새로고침한다. 결과적으로 SW 가 사라지고 항상 최신 빌드가 로드된다.
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
    wins.forEach(function (c) {
      try { c.navigate(c.url); } catch (e) {}
    });
  })());
});

// fetch 는 가로채지 않고 네트워크로 통과시킨다.
self.addEventListener('fetch', function (event) {});
