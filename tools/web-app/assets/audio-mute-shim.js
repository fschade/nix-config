// injected before the page runs: a kill switch for the page's sound, so a call
// can be silenced without leaving it. muting covers media elements: the ones in
// the DOM and detached `new Audio()` ones (tracked via the play hook). while
// muted the property setter clamps, so the page cant unmute itself mid-call.
// web audio is deliberately untouched: call apps route the outgoing mic through
// an AudioContext, suspending those silences the mic, not the speakers. remote
// voices play over media elements, only web-audio-only sounds (notification
// blips) slip through the mute.
(function () {
  var muted = false;
  var media = [];
  var track = function (list, item) { if (list.indexOf(item) === -1) list.push(item); };

  var apply = function () {
    [].slice.call(document.querySelectorAll('audio,video')).concat(media).forEach(function (el) {
      try { el.muted = muted; } catch (e) {}
    });
  };

  var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'muted');
  if (desc && desc.set) {
    Object.defineProperty(HTMLMediaElement.prototype, 'muted', {
      get: function () { return desc.get.call(this); },
      set: function (v) { desc.set.call(this, muted ? true : v); },
      configurable: true
    });
  }
  var play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function () {
    track(media, this);
    if (muted) { try { this.muted = true; } catch (e) {} }
    return play.apply(this, arguments);
  };

  // an autoplaying element added to the DOM never calls the js play(), sweep on
  // dom changes while muted
  var watch = function () {
    new MutationObserver(function () { if (muted) apply(); })
      .observe(document.documentElement, { childList: true, subtree: true });
  };
  if (document.documentElement) { watch(); } else { document.addEventListener('DOMContentLoaded', watch); }

  window.__webappSetMuted = function (value) { muted = !!value; apply(); };
})();
