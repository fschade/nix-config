import Cocoa
import WebKit

// the two mute toggles: page sound over the injected assets/audio-mute-shim.js
// (wired up in WebAppHost.swift), the mic over WebKit's capture state (the page
// just gets silence, its own mute UI doesnt know). both buttons are opt-in via
// the toolbar config (manifest `toolbar` / Settings).
extension AppDelegate {
    @objc func toggleAudioMute() {
        audioMuted.toggle()
        applyAudioMute()
        updateMuteButtons()
        emitPageEvent("muteAudio", ["state": audioMuted])
    }

    // also called after every page load (Browser.swift): a reload re-injects the
    // shim with muted=false, the native state has to win again
    func applyAudioMute() {
        webView.evaluateJavaScript("window.__webappSetMuted(\(audioMuted))") { _, error in
            if let error { NSLog("web-app: could not apply the sound mute: %@", error.localizedDescription) }
        }
    }

    @objc func toggleMicMute() {
        // only meaningful while the page captures; .none stays .none, the button
        // then just reads as "nothing to mute"
        let next: WKMediaCaptureState = webView.microphoneCaptureState == .muted ? .active : .muted
        webView.setMicrophoneCaptureState(next) { [weak self] in
            guard let self else { return }
            self.updateMuteButtons()
            self.emitPageEvent("muteMic", ["state": self.webView.microphoneCaptureState == .muted])
        }
    }

    func updateMuteButtons() {
        for item in window.toolbar?.items ?? [] {
            switch item.itemIdentifier {
            case .muteAudio:
                item.image = symbol(audioMuted ? "speaker.slash" : "speaker.wave.2", "Mute Sound")
                item.toolTip = audioMuted ? "Unmute Sound" : "Mute Sound"
            case .muteMic:
                let muted = webView.microphoneCaptureState == .muted
                item.image = symbol(muted ? "mic.slash" : "mic", "Mute Microphone")
                item.toolTip = muted ? "Unmute Microphone" : "Mute Microphone"
            default:
                break
            }
        }
    }

}
