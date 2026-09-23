import Cocoa
import WebKit

extension AppDelegate {
    @objc func toggleAudioMute() {
        audioMuted.toggle()
        applyAudioMute()
        updateMuteButtons()
        emitPageEvent("muteAudio", ["state": audioMuted])
    }

    func applyAudioMute() {
        webView.evaluateJavaScript("window.__webappSetMuted(\(audioMuted))") { _, error in
            if let error { NSLog("web-app: could not apply the sound mute: %@", error.localizedDescription) }
        }
    }

    @objc func toggleMicMute() {
        guard webView.microphoneCaptureState != .none else {
            micMutePending.toggle()
            updateMuteButtons()
            return
        }
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
                let muted = webView.microphoneCaptureState == .muted || micMutePending
                item.image = symbol(muted ? "mic.slash" : "mic", "Mute Microphone")
                item.toolTip = muted ? "Unmute Microphone" : "Mute Microphone"
            default:
                break
            }
        }
    }

}
