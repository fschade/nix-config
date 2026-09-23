// injected before the page runs: a kill switch for the page's sound, so a call
// can be silenced without leaving it. no mutation observer and no element
(function () {
  var muted = false;
  var MARK = '__webappMuted'; // true on an element = we muted it, unmute restores it

  var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'muted');
  var silence = function (el) {
    try { if (!desc.get.call(el)) { el[MARK] = true; desc.set.call(el, true); } } catch (e) {}
  };
  var restore = function (el) {
    try { if (el[MARK]) { delete el[MARK]; desc.set.call(el, false); } } catch (e) {}
  };
  var sync = function (el) { if (muted) { silence(el); } else { restore(el); } };

  if (desc && desc.set) {
    Object.defineProperty(HTMLMediaElement.prototype, 'muted', {
      get: function () { return desc.get.call(this); },
      set: function (v) {
        if (!muted) { desc.set.call(this, v); return; }
        this[MARK] = !v;
        desc.set.call(this, true);
      },
      configurable: true
    });
  }
  var play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function () {
    sync(this);
    return play.apply(this, arguments);
  };
  document.addEventListener('play', function (e) { sync(e.target); }, true);

  window.__webappSetMuted = function (value) {
    muted = !!value;
    [].slice.call(document.querySelectorAll('audio,video')).forEach(sync);
  };
})();
