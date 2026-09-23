// force the browser-side mic processing off: echo is handled by the mixer
// sitting in front of the mic, and an echo-cancelled capture makes macos
(() => {
  const {mediaDevices} = navigator;
  const original = mediaDevices.getUserMedia.bind(mediaDevices);
  mediaDevices.getUserMedia = (constraints) => {
    if (!constraints?.audio) return original(constraints);
    const audio = constraints.audio === true ? {} : constraints.audio;
    return original({
      ...constraints,
      audio: {...audio, echoCancellation: false, noiseSuppression: false, autoGainControl: false},
    });
  };
})();
