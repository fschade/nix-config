// injected before the page runs: replace window.Notification, so the page's
// desktop notifications get bridged to real macos ones over the handler
(function () {
  var post = function (m) {
    try { window.webkit.messageHandlers.notify.postMessage(m); } catch (e) {}
  };
  function N(title, options) {
    options = options || {};
    post({ title: String(title || ''), body: String(options.body || '') });
    this.onclick = this.onclose = this.onerror = this.onshow = null;
    this.close = function () {};
    this.addEventListener = function () {};
    this.removeEventListener = function () {};
  }
  N.permission = 'granted';
  N.maxActions = 2;
  N.requestPermission = function (cb) {
    post({ requestPermission: true });
    if (typeof cb === 'function') cb('granted');
    return Promise.resolve('granted');
  };
  try {
    Object.defineProperty(window, 'Notification', { value: N, configurable: true, writable: true });
  } catch (e) {
    window.Notification = N;
  }
})();
