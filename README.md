# Midivana

Midivana is an iPad MIDI controller built as a Swift Playgrounds app package. It includes a native SwiftUI performance surface, CoreMIDI output/input support, preset JSON files, motion controls, and an optional web view resource.

The Swift Playgrounds project is in `Midivana.swiftpm`.

## Requirements

- iPad with Swift Playgrounds installed
- iPadOS 18.1 or newer
- A MIDI destination, such as a Mac, synth, DAW, or CoreMIDI-compatible app
- Optional: Hammerspoon on macOS for turning Midivana MIDI CC pads into Mac key presses

## Open and Run on iPad

1. Download or clone this repository.
2. Move `Midivana.swiftpm` to iCloud Drive or AirDrop it to the iPad.
3. Open `Midivana.swiftpm` in Swift Playgrounds.
4. Tap Run.
5. Open the settings panel in Midivana and tap refresh if your MIDI devices are not listed.
6. Pick a MIDI output destination.
7. Play the pads, frets, sliders, or performance controls.

## MIDI Usage

Midivana sends MIDI from the selected output destination in settings. If no output is selected, it uses the first available CoreMIDI destination.

The app can send:

- Note on/off messages
- Control change messages
- Pitch bend
- All notes off / reset messages

It can also listen to a MIDI input source and track external active notes.

## Presets and Layouts

Bundled resources live in `Midivana.swiftpm/Resources`.

- `midivana-preset-Gradient-Circles.json` is the bundled visual/performance preset.
- `midivana-layout-Frets-and-sliders.json` is the bundled custom layout.
- `index.html` is bundled for the WebView-backed surface.

Preset and layout files are JSON, so they can be edited outside the app and reimported into the package.

## Mac Key Pads

Midivana includes optional Mac key pads that send MIDI CC messages. The included Hammerspoon script can receive those CCs on a Mac and turn them into keyboard events.

Default CC mapping:

- CC 80: Left arrow
- CC 81: Right arrow
- CC 82: Up arrow
- CC 83: Down arrow
- CC 84: I key

Setup:

1. Install Hammerspoon on the Mac.
2. Copy `Midivana.swiftpm/hammerspoon/midivana_keys.lua` into `~/.hammerspoon/init.lua`, or require it from your existing Hammerspoon config.
3. Reload Hammerspoon.
4. Connect the iPad to the Mac as a MIDI source in Audio MIDI Setup if needed.
5. In Midivana, choose the Mac as the MIDI output destination.
6. Enable `Show Mac key pads` in Midivana performance settings.

More details are in `Midivana.swiftpm/Resources/Docs/MacKeySetup.md`.

## Repository Contents

- `Midivana.swiftpm/` - Swift Playgrounds app package for iPad
- `Midivana.swiftpm/Resources/` - bundled app resources, presets, layouts, assets, and docs
- `Midivana.swiftpm/hammerspoon/` - optional macOS MIDI-to-key helper
- `index.html` - standalone web version
