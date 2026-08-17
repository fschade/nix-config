// the page-facing bridge, injected before everything else: window.webapp.state
// mirrors the native ui, every native action lands as a "webapp:<type>" custom
// event on window (webapp:ready carries the full state after each load), and
// setButtonState lets the page drive a toggle button from its side.
(function () {
  var state = { audioMuted: false, micMuted: false, buttons: {} };
  window.webapp = {
    state: state,
    setButtonState: function (name, value) {
      try {
        window.webkit.messageHandlers.webapp.postMessage(
          { action: 'buttonState', name: String(name), value: !!value });
      } catch (e) {}
    }
  };
  window.__webappEmit = function (type, detail) {
    detail = detail || {};
    // keep the snapshot current before any listener runs
    if (type === 'ready') {
      state.audioMuted = !!detail.audioMuted;
      state.micMuted = !!detail.micMuted;
      state.buttons = detail.buttons || {};
    }
    if (type === 'muteAudio') { state.audioMuted = !!detail.state; }
    if (type === 'muteMic') { state.micMuted = !!detail.state; }
    if (type === 'button' && 'state' in detail) { state.buttons[detail.name] = !!detail.state; }
    window.dispatchEvent(new CustomEvent('webapp:' + type, { detail: detail }));
  };
})();
