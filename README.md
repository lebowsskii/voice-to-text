<p align="center"><img src="docs/app-icon.png" width="96" height="96" alt="VoiceToText icon"></p>

<h1 align="center">VoiceToText</h1>

<p align="center">Dictation for macOS: press ⌘⌥Z, speak, get text at your cursor.</p>

## Features

- On-device transcription on the Apple Neural Engine — no audio leaves your Mac by default
- Floating panel with a live level meter and timer while recording
- ✓ or ⌘⌥Z again to finish and paste, ✕ or Esc to discard
- Clipboard is restored after pasting
- Switch engines anytime in Settings → Models, takes effect immediately

## Install

Download the latest `.dmg` from [Releases](../../releases), drag `VoiceToText.app` to `/Applications`.

The app isn't notarized, so Gatekeeper will block it on first launch. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/VoiceToText.app
```

## Demo

**Parakeet transcription (russian):**

https://github.com/user-attachments/assets/032bcbc4-a515-4352-ae47-cfe5a8abc982

## Engines

| Engine | Where it runs | Notes |
|---|---|---|
| Parakeet TDT v3 | On-device | 25 languages, default |
| Whisper Large v3 Turbo | On-device | Alternative local engine |
| Gemini | Cloud | Requires your own API key |

## Requirements

- macOS 15.0+
- Local engines download their models on first use (a few hundred MB each)

## Build from source

Open `VoiceToText.xcodeproj` in Xcode 26 and press ⌘R, or run the test suite:

```bash
xcodebuild test -scheme VoiceToText -destination 'platform=macOS'
```

## License

MIT, see [LICENSE](LICENSE).
