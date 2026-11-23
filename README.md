# Pressly

Satisfying mechanical keyboard sounds with every keystroke. Pressly is a menu-bar app that plays
**studio-recorded switch sounds** as you type in any app: a press and a release for every key,
deeper sounds for the space bar and big keys, and stereo placement that follows the keyboard.

## Features
- **15 recorded switches:** NovelKeys Cream, Gateron Black Ink, Alpaca V2, Gateron Red Ink, Zeal Tealios,
  Cherry MX Black, Holy Panda, Topre, Everglide Oreo, Everglide Crystal Purple, Cherry MX Brown,
  IBM Buckling Spring, Kailh Box Navy, SKCM Blue Alps and Cherry MX Blue
- **10 Pressly Originals:** synthesized sounds (linear, tactile, clicky, a typewriter with a bell, a musical pad)
- **Realistic playback:** separate press/release takes per keyboard row, randomized pitch, spatial audio,
  optional modifier, function/media key and numpad sounds, ~5 ms output latency
- **Mouse & scroll:** click sounds, scroll ticks and Force Touch haptic ticks
- **Sleep triggers:** goes quiet while gaming, screen sharing, playing media, in a calendar meeting or with a Focus on
- **Muting:** per-app mute, and per-output mute (e.g. stay silent on office speakers)
- **Output picker:** play through any audio device
- **Shortcuts:** ⌃⌥⌘K on/off, ⌃⌥⌘N next switch (both rebindable); `pressly://` links; AppleScript
- **Stats:** keystrokes, words and clicks per day, a 14-day chart and most-pressed keys (counts only, never text)
- **Live keyboard** in Settings, switch gallery with previews, switch-change pop-up, dynamic Dock icon,
  hideable/customizable menu bar icon, open at login, guided onboarding

## Privacy
Pressly only sees which key was pressed, never what you type. Password fields are hidden from it by macOS.
Nothing is uploaded; stats stay in `~/Library/Application Support/Pressly`.

## Layout
- `Sources/Pressly` — the app. `InputMonitor` (global key/mouse/scroll events), `Controller` (rules: when to
  play, pan, stats), `SoundEngine` (AVAudioEngine player pool, output device), `Recordings` (loads and
  loudness-matches the recorded switches), `Synth` + `Profiles` (switch definitions, synthesized sounds),
  `SleepTriggers`, `HotKeys`, `Stats`, and the SwiftUI views.
- `Resources/Recordings` — the recorded switch sounds and their licenses (`CREDITS.txt`).
- `Resources/Pressly.sdef` — the AppleScript dictionary.

## AppleScript
```applescript
tell application "Pressly"
    set current switch to "Holy Panda"
    set sound volume to 60
    toggle sounds
    keystrokes today
end tell
```

## Build
Requires macOS 14+ and Xcode (the build script picks its toolchain automatically).

    ./scripts/make-signing.sh       # once: stable local signing so Accessibility survives rebuilds
    ./scripts/build-app.sh          # build/Pressly.app
    ./scripts/package.sh            # dist/Pressly-<version>.pkg, .dmg, .zip and How to Install.txt

Debug builds support `build/Pressly.app/Contents/MacOS/Pressly --snapshot <dir>` (PNG of every screen) and
`--render-samples <dir>` (writes every switch's sounds as WAV).

See `installer/How to Install.txt` for install steps and troubleshooting.

## Credits
The recorded switch sounds come from two MIT-licensed open-source projects:
[Mechanical Keyboard Simulator (kbsim)](https://github.com/tplai/kbsim) by Thomas Lai and
[Mechvibes](https://github.com/hainguyents13/mechvibes) by Hải Nguyễn. Their license notices are in
`Resources/Recordings/CREDITS.txt`. Switch names are used only to describe the recordings; Pressly isn't
affiliated with any switch maker.

## License
MIT. See `LICENSE`.
