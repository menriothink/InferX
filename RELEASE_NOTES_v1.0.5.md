## What's New in v1.0.5

### Highlights
- Updated documentation with macOS screenshots and clearer provider support (OpenAI-compatible APIs + GitHub Copilot).
- macOS chat UI polish: per-message model/stats layout is easier to read and aligns with message content.
- iOS UX improvements: sidebars and model manager navigation gestures, better spacing/tint, and keyboard dismissal on model settings.

### Notes
- The shipped app is **ad-hoc signed** (not notarized). If Gatekeeper blocks it, use **Right‑click → Open**, or remove quarantine:

```bash
xattr -cr /Applications/InferX.app
open /Applications/InferX.app
```

### System Requirements
- macOS 15.0 (Sequoia) or later

