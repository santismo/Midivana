import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PhotosUI

struct SettingsSheet: View {
  @ObservedObject var app: AppModel
  @ObservedObject private var midi: MIDIService
  @ObservedObject private var presetStore: PresetStore

  @Environment(\.dismiss) private var dismiss
  @State private var presetName = ""
  @State private var isImporting = false
  @State private var isExporting = false
  @State private var exportDocument = JSONTextDocument()
  @State private var importError: String?
  var onDone: (() -> Void)?

  init(app: AppModel, onDone: (() -> Void)? = nil) {
    self.app = app
    self.midi = app.midi
    self.presetStore = app.presetStore
    self.onDone = onDone
  }

  var body: some View {
    Form {
      DisclosureGroup("MIDI") { midiSection }
      DisclosureGroup("Performance") { performanceSection }
      DisclosureGroup("Key Pads") { keyPadsSection }
      DisclosureGroup("Velocity") { velocitySection }
      DisclosureGroup("Fretboard") { fretboardSection }
      DisclosureGroup("Keyboard") { keyboardSection }
      DisclosureGroup("Drums") { drumsSection }
      DisclosureGroup("Expression") { expressionSection }
      DisclosureGroup("Theme") { themeSection }
      DisclosureGroup("Custom Layout") { customLayoutSection }
      DisclosureGroup("Presets") { presetsSection }
    }
    .scrollContentBackground(.hidden)
    .background(app.preset.theme.background.color)
      .onChange(of: app.preset.showMacKeyPads) { _, _ in
        UserDefaults.standard.set(true, forKey: "MidivanaMacKeyPadsUserConfigured")
      }
      .onAppear {
        presetName = app.preset.name
      }
      .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
        importPreset(result)
      }
      .fileExporter(
        isPresented: $isExporting,
        document: exportDocument,
        contentType: .json,
        defaultFilename: "\(safeFileName(app.preset.name)).json"
      ) { _ in }
      .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
        Button("OK", role: .cancel) { importError = nil }
      } message: {
        Text(importError ?? "")
      }
    .preferredColorScheme(.dark)
    .presentationDetents([.large])
  }

  private var midiSection: some View {
    Section("MIDI") {
      Picker("Output", selection: $app.selectedOutputID) {
        Text("First available").tag(Int32?.none)
        ForEach(midi.outputs) { output in
          Text(output.name).tag(Int32?.some(output.id))
        }
      }

      Picker("Input monitor", selection: $app.selectedInputID) {
        Text("All inputs").tag(Int32?.none)
        ForEach(midi.inputs) { input in
          Text(input.name).tag(Int32?.some(input.id))
        }
      }

      Stepper("Channel \(app.preset.midiChannel)", value: $app.preset.midiChannel, in: 1...16)

      if !midi.lastIncomingMessage.isEmpty {
        Text("Last input: \(midi.lastIncomingMessage.map { String(format: "%02X", $0) }.joined(separator: " "))")
          .font(.caption.monospaced())
      }

      if !midi.lastOutgoingMessage.isEmpty {
        Text("Last output: \(midi.lastOutgoingMessage.map { String(format: "%02X", $0) }.joined(separator: " "))")
          .font(.caption.monospaced())
      }

      Button {
        app.refreshMIDI()
      } label: {
        Label("Refresh MIDI Devices", systemImage: "arrow.clockwise")
      }
    }
  }

  private var performanceSection: some View {
    Section(header: Text("Performance")) {
      Picker("Layout", selection: layoutBinding) {
        ForEach(PerformanceLayout.allCases) { layout in
          Label(layout.title, systemImage: layout.systemImage).tag(layout)
        }
      }

      Picker("Root", selection: $app.preset.rootNote) {
        ForEach(0..<12, id: \.self) { pitch in
          Text(MusicTheory.pitchName(pitch)).tag(pitch)
        }
      }

      Picker("Scale", selection: $app.preset.scale) {
        ForEach(ScaleKind.allCases) { scale in
          Text(scale.title).tag(scale)
        }
      }

      Picker("Sustain", selection: $app.preset.sustainMode) {
        ForEach(SustainMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }

      Stepper("Base octave \(app.preset.baseOctave)", value: $app.preset.baseOctave, in: 1...7)

      Toggle("Show Mac key pads", isOn: $app.preset.showMacKeyPads)
      Toggle("Show note repeat button", isOn: $app.preset.showNoteRepeatControls)
      if app.preset.showMacKeyPads {
        Stepper("Key pad press value \(app.preset.keyPadPressValue)", value: $app.preset.keyPadPressValue, in: 64...127)
        Button {
          app.resetKeyPadsToDefaultRow()
        } label: {
          Label("Reset Default Key Row", systemImage: "arrow.counterclockwise")
        }
      }
    }
  }

  private var keyPadsSection: some View {
    Section("Keyboard CC Buttons") {
      Toggle("Show Mac key pads", isOn: $app.preset.showMacKeyPads)
      Toggle("Edit arrangement in mini window", isOn: keyPadEditModeBinding)
      Stepper("Default press value \(app.preset.keyPadPressValue)", value: $app.preset.keyPadPressValue, in: 1...127)

      KeyPadArrangeEditor(app: app)
        .frame(height: 148)

      ForEach($app.preset.keyPads) { $keyPad in
        DisclosureGroup("\(keyPad.label.isEmpty ? "Key" : keyPad.label)  CC \(keyPad.cc)") {
          TextField("Label", text: $keyPad.label)
          Stepper("CC \(keyPad.cc)", value: $keyPad.cc, in: 0...127)
          Stepper("Press value \(keyPad.pressValue)", value: $keyPad.pressValue, in: 1...127)
          SliderRow(title: "X \(Int(keyPad.x * 100))%", value: $keyPad.x, range: 0...1)
          SliderRow(title: "Y \(Int(keyPad.y * 100))%", value: $keyPad.y, range: 0...1)
          SliderRow(title: "W \(Int(keyPad.width * 100))%", value: $keyPad.width, range: 0.06...1)
          SliderRow(title: "H \(Int(keyPad.height * 100))%", value: $keyPad.height, range: 0.12...1)

          HStack {
            Button {
              app.duplicateKeyPad(keyPad)
            } label: {
              Label("Copy", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive) {
              app.deleteKeyPad(keyPad)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
    }
  }

  private var keyPadEditModeBinding: Binding<Bool> {
    Binding {
      app.preset.keyPadEditMode
    } set: { enabled in
      app.setKeyPadEditMode(enabled)
    }
  }

  private var velocitySection: some View {
    Section(header: Text("Velocity")) {
      Picker("Mode", selection: $app.preset.velocityMode) {
        ForEach(VelocityMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }

      if app.preset.velocityMode == .fixed {
        IntSliderRow(title: "Fixed output \(app.preset.velocity)", value: $app.preset.velocity, range: 1...127)
      } else {
        VelocityRangeSlider(
          title: "Output range \(app.preset.velocityMin)-\(app.preset.velocityMax)",
          lower: $app.preset.velocityMin,
          upper: $app.preset.velocityMax,
          range: 1...127
        )
      }
      Text("Last sent velocity: \(app.lastSentVelocity)")
        .font(.caption.monospaced())

      Picker("Response curve", selection: $app.preset.velocityCurve) {
        Text("Linear").tag("linear")
        Text("Soft").tag("soft")
        Text("Hard").tag("hard")
        Text("Extreme").tag("extreme")
      }

      SliderRow(title: "Accel sensitivity \(Int(app.preset.accelSensitivity * 100))%", value: $app.preset.accelSensitivity, range: 0...4)
      SliderRow(title: "Touch force \(Int(app.preset.touchForceSensitivity * 100))%", value: $app.preset.touchForceSensitivity, range: 0...2)
      SliderRow(title: "Accel floor \(String(format: "%.2f", app.preset.accelFloor))", value: $app.preset.accelFloor, range: 0...0.6)
      SliderRow(title: "Accel max \(String(format: "%.2f", app.preset.accelMax))", value: $app.preset.accelMax, range: 0.2...2.0)
      Text("Accel: \(app.motion.acceleration, specifier: "%.3f")")
        .font(.caption.monospaced())
    }
  }

  private var fretboardSection: some View {
    Section(header: Text("Fretboard")) {
      Stepper("Frets \(app.preset.fretCount)", value: $app.preset.fretCount, in: 4...25)
      ForEach(app.preset.stringTunings.indices, id: \.self) { index in
        Stepper(
          "String \(index + 1) \(MusicTheory.noteName(app.preset.stringTunings[index]))",
          value: $app.preset.stringTunings[index],
          in: 0...127
        )
        Stepper("String \(index + 1) channel \(app.preset.stringChannels[index])", value: $app.preset.stringChannels[index], in: 1...16)
      }
    }
  }

  private var keyboardSection: some View {
    Section(header: Text("Keyboard")) {
      Stepper("Octaves \(app.preset.keyboardOctaves)", value: $app.preset.keyboardOctaves, in: 1...4)
      Stepper("Rows \(app.preset.keyboardRows)", value: $app.preset.keyboardRows, in: 1...4)
    }
  }

  private var drumsSection: some View {
    Section(header: Text("Drums")) {
      Stepper("Toms \(app.preset.drumTomCount)", value: $app.preset.drumTomCount, in: 1...12)
      Stepper("Tom rows \(app.preset.drumTomRows)", value: $app.preset.drumTomRows, in: 1...3)
      Stepper("Cymbals \(app.preset.drumCymbalCount)", value: $app.preset.drumCymbalCount, in: 1...12)
      Stepper("Cymbal rows \(app.preset.drumCymbalRows)", value: $app.preset.drumCymbalRows, in: 1...3)
      Toggle("Flip sides", isOn: $app.preset.drumFlip)
      ForEach(app.preset.drumMap.indices, id: \.self) { index in
        Stepper("Pad \(index + 1) \(MusicTheory.noteName(app.preset.drumMap[index]))", value: $app.preset.drumMap[index], in: 0...127)
      }
    }
  }

  private var expressionSection: some View {
    Section("Expression") {
      Toggle("Motion to CC", isOn: $app.preset.motionToCC)
      Stepper("Motion CC \(app.preset.motionCC)", value: $app.preset.motionCC, in: 0...127)
        .disabled(!app.preset.motionToCC)

      Stepper("Fretboard CC sliders \(app.preset.quickCCVisibleCount)", value: $app.preset.quickCCVisibleCount, in: 0...6)
      ForEach(0..<max(app.preset.quickCCVisibleCount, app.preset.quickCCNumbers.count), id: \.self) { index in
        if index < app.preset.quickCCVisibleCount {
          Stepper("CC slider \(index + 1): \(quickCCBinding(index).wrappedValue)", value: quickCCBinding(index), in: 0...127)
        }
      }

      Toggle("Pitch bend drag", isOn: $app.preset.pitchBendEnabled)
      Stepper("Pitch bend range \(app.preset.pitchBendRange) st", value: $app.preset.pitchBendRange, in: 1...12)
        .disabled(!app.preset.pitchBendEnabled)

      Toggle("Vibrato", isOn: $app.preset.vibratoEnabled)
      SliderRow(title: "Vibrato rate \(String(format: "%.1f", app.preset.vibratoRate)) Hz", value: $app.preset.vibratoRate, range: 0.5...12)
        .disabled(!app.preset.vibratoEnabled)
      SliderRow(title: "Vibrato depth \(String(format: "%.2f", app.preset.vibratoDepth))", value: $app.preset.vibratoDepth, range: 0.05...1)
        .disabled(!app.preset.vibratoEnabled)
    }
  }

  private var themeSection: some View {
    Section("Theme") {
      Picker("Pad shape", selection: $app.preset.theme.shape) {
        ForEach(PadShape.allCases) { shape in
          Text(shape.title).tag(shape)
        }
      }

      Toggle("Show note names", isOn: $app.preset.theme.showNoteNames)
      Toggle("Glow on touch", isOn: $app.preset.theme.glowOnTouch)
      Toggle("Scale on touch", isOn: $app.preset.theme.scaleOnTouch)
      Toggle("Pulse glow", isOn: $app.preset.theme.pulseGlow)
      Toggle("Hue shift", isOn: $app.preset.theme.hueShift)
      SliderRow(title: "Hue amount \(Int(app.preset.theme.hueShiftAmount)) degrees", value: $app.preset.theme.hueShiftAmount, range: 0...720)
      SliderRow(title: "Hue speed \(String(format: "%.1f", app.preset.theme.hueShiftSpeed))s", value: $app.preset.theme.hueShiftSpeed, range: 1...30)
      SliderRow(title: "Pad shift \(Int(app.preset.theme.huePadAmount)) degrees", value: $app.preset.theme.huePadAmount, range: 0...720)
      SliderRow(title: "Background drift \(Int(app.preset.theme.hueBackgroundDrift * 100))%", value: $app.preset.theme.hueBackgroundDrift, range: 0...1)
      SliderRow(title: "Blend intensity \(Int(app.preset.theme.hueBlendIntensity * 100))%", value: $app.preset.theme.hueBlendIntensity, range: 0...1)

      Button {
        app.randomizeColorsForHueBlend()
      } label: {
        Label("Randomize Colors + Hue Blend", systemImage: "shuffle")
      }

      Button {
        app.preset.theme.hueShift = true
        app.preset.theme.colorMode = "gradient"
        app.preset.theme.gradientTop = CodableColor(hex: 0x31D8FF)
        app.preset.theme.gradientBottom = CodableColor(hex: 0xFF7A3D)
        app.preset.theme.activePad = CodableColor(hex: 0xFFFFFF)
        app.preset.theme.hueShiftAmount = 360
        app.preset.theme.huePadAmount = 180
        app.preset.theme.hueBackgroundDrift = 0.35
        app.preset.theme.hueBlendIntensity = 0.45
        app.preset.theme.hueShiftSpeed = 8
      } label: {
        Label("Use Visible Hue Gradient", systemImage: "paintpalette")
      }

      Picker("Color mode", selection: $app.preset.theme.colorMode) {
        Text("Custom").tag("custom")
        Text("String gradient").tag("gradient")
      }

      Picker("Controls fill", selection: $app.preset.theme.controlFill) {
        Text("Solid").tag("solid")
        Text("Transparent").tag("outline")
      }

      Picker("Pads fill", selection: $app.preset.theme.padFillMode) {
        Text("Solid").tag("solid")
        Text("Transparent").tag("outline")
      }

      DisclosureGroup("Markers") {
        Picker("Mode", selection: $app.preset.theme.markerMode) {
          Text("Edges").tag("edges")
          Text("Pads").tag("pads")
          Text("Both").tag("both")
          Text("Off").tag("off")
        }

        Picker("Shape", selection: $app.preset.theme.markerShape) {
          Text("Dot").tag("dot")
          Text("Bar").tag("bar")
          Text("Square").tag("square")
          Text("Diamond").tag("diamond")
        }

        SliderRow(title: "Marker distance \(Int(app.preset.theme.markerOffset))px", value: $app.preset.theme.markerOffset, range: -400...400)
        ColorPicker("Marker color", selection: colorBinding(\.markerColor), supportsOpacity: true)
      }

      DisclosureGroup("Spacing") {
        SliderRow(title: "Pad gap \(Int(app.preset.theme.padGap))px", value: $app.preset.theme.padGap, range: 2...24)
        SliderRow(title: "Row gap \(Int(app.preset.theme.rowGap))px", value: $app.preset.theme.rowGap, range: 0...24)
      }

      ColorPicker("Background", selection: colorBinding(\.background), supportsOpacity: true)
      ColorPicker("Panel", selection: colorBinding(\.panel), supportsOpacity: true)
      ColorPicker("Pad", selection: colorBinding(\.pad), supportsOpacity: true)
      ColorPicker("Scale pad", selection: colorBinding(\.scalePad), supportsOpacity: true)
      ColorPicker("Active pad", selection: colorBinding(\.activePad), supportsOpacity: true)
      SliderRow(title: "Pad border thickness \(String(format: "%.1f", app.preset.theme.padBorderWidth))px", value: $app.preset.theme.padBorderWidth, range: 0.5...8)
      ColorPicker("Gradient top", selection: colorBinding(\.gradientTop), supportsOpacity: true)
      ColorPicker("Gradient bottom", selection: colorBinding(\.gradientBottom), supportsOpacity: true)
      ColorPicker("Pad border", selection: colorBinding(\.padBorder), supportsOpacity: true)
      ColorPicker("Pad glow", selection: colorBinding(\.padGlow), supportsOpacity: true)
      ColorPicker("Active glow", selection: colorBinding(\.activeGlow), supportsOpacity: true)
      ColorPicker("Accent", selection: colorBinding(\.accent), supportsOpacity: true)
    }
  }

  private var customLayoutSection: some View {
    Section("Custom Layout") {
      TextField("Layout name", text: $app.preset.customLayout.name)
      Toggle("Snap to grid", isOn: $app.preset.customLayout.snapToGrid)
      Toggle("Flip custom pads left/right", isOn: $app.preset.customLayout.flipHorizontal)
      Toggle("Show custom pad labels", isOn: $app.preset.customLayout.showLabels)
      Stepper("Grid columns \(app.preset.customLayout.gridColumns)", value: $app.preset.customLayout.gridColumns, in: 2...64)
      Stepper("Grid rows \(app.preset.customLayout.gridRows)", value: $app.preset.customLayout.gridRows, in: 2...64)

      HStack {
        Button {
          addCustomItem(.note)
        } label: {
          Label("Note", systemImage: "plus.square")
        }

        Button {
          addCustomItem(.ccSliderX)
        } label: {
          Label("Slider", systemImage: "slider.horizontal.3")
        }
      }

      HStack {
        Button {
          addCustomItem(.ccSliderY)
        } label: {
          Label("Slider V", systemImage: "slider.vertical.3")
        }

        Button {
          addCustomItem(.label)
        } label: {
          Label("Label", systemImage: "textformat")
        }
      }

      HStack {
        Button {
          addCustomItem(.sustain)
        } label: {
          Label("Sustain", systemImage: "pause.rectangle")
        }

        Button(role: .destructive) {
          addCustomItem(.panic)
        } label: {
          Label("Panic", systemImage: "stop.circle")
        }
      }

      HStack {
        Button {
          addCustomItem(.image)
        } label: {
          Label("Image", systemImage: "photo")
        }

        Button {
          addCustomItem(.video)
        } label: {
          Label("Video", systemImage: "video")
        }
      }

      Button {
        addCustomItem(.keyCommand)
      } label: {
        Label("Key command", systemImage: "keyboard")
      }

      HStack {
        Button {
          app.preset.customLayout = .editableFretboard
        } label: {
          Label("Fretboard", systemImage: "guitars")
        }

        Button {
          app.preset.customLayout = .editableDrumset
        } label: {
          Label("Drumset", systemImage: "drum")
        }
      }

      HStack {
        Button {
          app.preset.customLayout = .fretsAndSliders
        } label: {
          Label("Frets + Sliders", systemImage: "wand.and.stars")
        }

        Button(role: .destructive) {
          app.preset.customLayout.items.removeAll()
        } label: {
          Label("Clear", systemImage: "trash")
        }
      }

      ForEach($app.preset.customLayout.items) { $item in
        DisclosureGroup(item.label.isEmpty ? item.kind.title : item.label) {
          Picker("Kind", selection: $item.kind) {
            ForEach(CustomItemKind.allCases) { kind in
              Text(kind.title).tag(kind)
            }
          }

          TextField("Label", text: $item.label)
          Stepper("Note \(item.note) \(MusicTheory.noteName(item.note))", value: $item.note, in: 0...127)
          Stepper("Channel \(item.channel)", value: $item.channel, in: 1...16)
          Stepper("CC \(item.cc)", value: $item.cc, in: 0...127)
          TextField("Key command", text: $item.keyCommand)

          Picker("Shape", selection: $item.shape) {
            ForEach(PadShape.allCases) { shape in
              Text(shape.title).tag(shape)
            }
          }

          SliderRow(title: "X \(Int(item.x * 100))%", value: $item.x, range: 0...0.95)
          SliderRow(title: "Y \(Int(item.y * 100))%", value: $item.y, range: 0...0.95)
          SliderRow(title: "W \(Int(item.width * 100))%", value: $item.width, range: 0.05...0.9)
          SliderRow(title: "H \(Int(item.height * 100))%", value: $item.height, range: 0.05...0.9)
          SliderRow(title: "Label size \(Int(item.labelSize))px", value: $item.labelSize, range: 12...160)
          SliderRow(title: "Rotate \(Int(item.rotation)) degrees", value: $item.rotation, range: -180...180)

          ColorPicker("Fill", selection: colorBinding($item.fill), supportsOpacity: true)
          ColorPicker("Active", selection: colorBinding($item.activeFill), supportsOpacity: true)
          HStack {
            Button {
              duplicate(item)
            } label: {
              Label("Copy", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive) {
              delete(item)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
          CustomItemImageControls(item: $item)
        }
      }
      .onDelete { offsets in
        app.preset.customLayout.items.remove(atOffsets: offsets)
      }
    }
  }

  private var presetsSection: some View {
    Section("Presets") {
      TextField("Preset name", text: $presetName)
        .textInputAutocapitalization(.words)

      HStack {
        Button {
          app.saveCurrentPreset(named: presetName)
          presetName = app.preset.name
        } label: {
          Label("Save Copy", systemImage: "plus.square.on.square")
        }

        Button {
          app.updateCurrentPreset(named: presetName)
        } label: {
          Label("Update", systemImage: "square.and.arrow.down")
        }
      }

      HStack {
        Button {
          prepareExport()
        } label: {
          Label("Export", systemImage: "square.and.arrow.up")
        }

        Button {
          isImporting = true
        } label: {
          Label("Import", systemImage: "square.and.arrow.down.on.square")
        }
      }

      ForEach(presetStore.presets) { preset in
        HStack {
          Button {
            app.apply(preset)
            presetName = preset.name
          } label: {
            VStack(alignment: .leading) {
              Text(preset.name)
              Text("\(preset.layout.title) - Ch \(preset.midiChannel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)

          Spacer()

          Button(role: .destructive) {
            app.delete(preset)
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(.borderless)
        }
      }
    }
  }

  private var layoutBinding: Binding<PerformanceLayout> {
    Binding {
      app.preset.layout
    } set: { newLayout in
      app.setLayout(newLayout)
    }
  }

  private func colorBinding(_ keyPath: WritableKeyPath<ThemeSettings, CodableColor>) -> Binding<Color> {
    Binding {
      app.preset.theme[keyPath: keyPath].color
    } set: { color in
      app.preset.theme[keyPath: keyPath] = CodableColor(color)
    }
  }

  private func colorBinding(_ binding: Binding<CodableColor>) -> Binding<Color> {
    Binding {
      binding.wrappedValue.color
    } set: { color in
      binding.wrappedValue = CodableColor(color)
    }
  }

  private func quickCCBinding(_ index: Int) -> Binding<Int> {
    Binding {
      guard app.preset.quickCCNumbers.indices.contains(index) else { return index == 0 ? app.preset.cc1Number : app.preset.cc2Number }
      return app.preset.quickCCNumbers[index]
    } set: { value in
      while app.preset.quickCCNumbers.count <= index {
        app.preset.quickCCNumbers.append(index == 0 ? app.preset.cc1Number : app.preset.cc2Number)
      }
      app.preset.quickCCNumbers[index] = value.clamped(to: 0...127)
      if index == 0 { app.preset.cc1Number = value.clamped(to: 0...127) }
      if index == 1 { app.preset.cc2Number = value.clamped(to: 0...127) }
    }
  }

  private func addCustomItem(_ kind: CustomItemKind) {
    let count = app.preset.customLayout.items.count
    var item = CustomItem()
    item.kind = kind
    item.label = defaultCustomLabel(kind: kind, count: count)
    item.note = 60 + (count % 24)
    item.cc = kind == .ccSliderX || kind == .ccSliderY ? app.preset.cc1Number : 1
    item.x = 0.08 + Double(count % 4) * 0.18
    item.y = 0.12 + Double((count / 4) % 4) * 0.18
    item.width = kind == .note ? 0.14 : 0.32
    item.height = kind == .note ? 0.14 : 0.1
    if kind == .sustain || kind == .panic {
      item.width = 0.18
      item.height = 0.12
    }
    if kind == .image {
      item.width = 0.24
      item.height = 0.24
      item.shape = .rounded
    }
    if kind == .video {
      item.width = 0.34
      item.height = 0.24
      item.shape = .rounded
    }
    if kind == .keyCommand {
      item.width = 0.16
      item.height = 0.13
      item.keyCommand = "ArrowLeft"
      item.label = "Left"
    }
    app.preset.customLayout.items.append(item)
  }

  private func defaultCustomLabel(kind: CustomItemKind, count: Int) -> String {
    switch kind {
    case .note: return "Pad \(count + 1)"
    case .ccSliderX: return "CC \(app.preset.cc1Number)"
    case .ccSliderY: return "CC \(app.preset.cc1Number)"
    case .label: return "Label"
    case .sustain: return "Sustain"
    case .panic: return "Panic"
    case .image: return "Image"
    case .video: return "Video"
    case .keyCommand: return "Key"
    }
  }

  private func duplicate(_ item: CustomItem) {
    var copy = item
    copy.id = UUID()
    copy.x = min(0.95, copy.x + 0.04)
    copy.y = min(0.95, copy.y + 0.04)
    app.preset.customLayout.items.append(copy)
  }

  private func delete(_ item: CustomItem) {
    app.preset.customLayout.items.removeAll { $0.id == item.id }
  }

  private func prepareExport() {
    do {
      let data = try app.exportCurrentPresetData()
      exportDocument = JSONTextDocument(text: String(data: data, encoding: .utf8) ?? "{}")
      isExporting = true
    } catch {
      importError = error.localizedDescription
    }
  }

  private func importPreset(_ result: Result<URL, Error>) {
    do {
      let url = try result.get()
      let canAccess = url.startAccessingSecurityScopedResource()
      defer {
        if canAccess {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let data = try Data(contentsOf: url)
      try app.importPresetData(data)
      presetName = app.preset.name
    } catch {
      importError = error.localizedDescription
    }
  }

  private func safeFileName(_ name: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
    let filtered = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    return String(filtered).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Midivana-Preset" : String(filtered)
  }
}

private struct KeyPadArrangeEditor: View {
  @ObservedObject var app: AppModel
  @State private var selectedID: UUID?
  @State private var dragStart: [UUID: CGPoint] = [:]

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Button {
          app.addKeyPad()
          selectedID = app.preset.keyPads.last?.id
        } label: {
          Label("Add", systemImage: "plus")
        }

        Button(role: .destructive) {
          removeSelected()
        } label: {
          Label("Remove", systemImage: "minus")
        }
        .disabled(app.preset.keyPads.isEmpty)

        Button {
          app.resetKeyPadsToDefaultRow()
          selectedID = app.preset.keyPads.first?.id
        } label: {
          Label("Reset", systemImage: "arrow.counterclockwise")
        }
      }

      GeometryReader { proxy in
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))

          ForEach($app.preset.keyPads) { $keyPad in
            arrangeKey($keyPad, in: proxy.size)
          }
        }
      }
    }
  }

  private func removeSelected() {
    if let selectedID, app.preset.keyPads.contains(where: { $0.id == selectedID }) {
      app.deleteKeyPad(id: selectedID)
    } else {
      app.deleteLastKeyPad()
    }
    selectedID = app.preset.keyPads.last?.id
  }

  private func arrangeKey(_ keyPad: Binding<MacKeyPad>, in size: CGSize) -> some View {
    let pad = keyPad.wrappedValue.normalized
    let width = max(28, size.width * CGFloat(pad.width))
    let height = max(28, size.height * CGFloat(pad.height))
    let isSelected = selectedID == pad.id
    return Text(pad.label)
      .font(.caption.weight(.bold))
      .lineLimit(1)
      .minimumScaleFactor(0.55)
      .frame(width: width, height: height)
      .background(app.preset.theme.panel.color.opacity(0.88), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .stroke(isSelected ? app.preset.theme.activeGlow.color : app.preset.theme.padBorder.color.opacity(0.45), lineWidth: isSelected ? 2 : 1)
      )
      .position(
        x: size.width * CGFloat(pad.x + pad.width / 2),
        y: size.height * CGFloat(pad.y + pad.height / 2)
      )
      .contentShape(Rectangle())
      .onTapGesture {
        selectedID = pad.id
      }
      .gesture(keyDragGesture(keyPad, in: size))
  }

  private func keyDragGesture(_ keyPad: Binding<MacKeyPad>, in size: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let id = keyPad.wrappedValue.id
        selectedID = id
        if dragStart[id] == nil {
          dragStart[id] = CGPoint(x: keyPad.wrappedValue.x, y: keyPad.wrappedValue.y)
        }
        guard let start = dragStart[id] else { return }
        var next = keyPad.wrappedValue
        next.x = Double(start.x) + Double(value.translation.width / max(1, size.width))
        next.y = Double(start.y) + Double(value.translation.height / max(1, size.height))
        keyPad.wrappedValue = next.normalized
      }
      .onEnded { _ in
        dragStart.removeValue(forKey: keyPad.wrappedValue.id)
      }
  }
}

private struct CustomItemImageControls: View {
  @Binding var item: CustomItem
  @State private var restSelection: PhotosPickerItem?
  @State private var activeSelection: PhotosPickerItem?

  var body: some View {
    PhotosPicker(selection: $restSelection, matching: .images) {
      Label(item.imageData == nil ? "Set image" : "Replace image", systemImage: "photo")
    }
    .onChange(of: restSelection) { _, newItem in
      load(newItem, active: false)
    }

    PhotosPicker(selection: $activeSelection, matching: .images) {
      Label(item.activeImageData == nil ? "Set active image" : "Replace active image", systemImage: "photo.fill")
    }
    .onChange(of: activeSelection) { _, newItem in
      load(newItem, active: true)
    }

    if item.imageData != nil || item.activeImageData != nil {
      Button(role: .destructive) {
        item.imageData = nil
        item.activeImageData = nil
      } label: {
        Label("Clear images", systemImage: "trash")
      }
    }
  }

  private func load(_ selection: PhotosPickerItem?, active: Bool) {
    guard let selection else { return }
    Task {
      if let data = try? await selection.loadTransferable(type: Data.self) {
        await MainActor.run {
          if active {
            item.activeImageData = data
          } else {
            item.imageData = data
          }
        }
      }
    }
  }
}

private struct SliderRow: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.medium))
      Slider(value: $value, in: range, step: 0.01)
    }
  }
}

private struct IntSliderRow: View {
  let title: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.medium))
      Slider(
        value: Binding(
          get: { Double(value) },
          set: { value = Int($0.rounded()).clamped(to: range) }
        ),
        in: Double(range.lowerBound)...Double(range.upperBound),
        step: 1
      )
    }
  }
}

private struct VelocityRangeSlider: View {
  let title: String
  @Binding var lower: Int
  @Binding var upper: Int
  let range: ClosedRange<Int>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption.weight(.medium))
      GeometryReader { proxy in
        let width = max(1, proxy.size.width)
        let lowerX = position(for: lower, width: width)
        let upperX = position(for: upper, width: width)
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 6)
            .position(x: width / 2, y: 18)

          Capsule()
            .fill(Color.accentColor)
            .frame(width: max(0, upperX - lowerX), height: 6)
            .position(x: lowerX + max(0, upperX - lowerX) / 2, y: 18)

          handle(x: lowerX)
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  lower = min(valueFor(x: value.location.x, width: width), upper)
                }
            )

          handle(x: upperX)
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  upper = max(valueFor(x: value.location.x, width: width), lower)
                }
            )
        }
      }
      .frame(height: 38)
    }
  }

  private func handle(x: CGFloat) -> some View {
    Circle()
      .fill(Color.accentColor)
      .frame(width: 28, height: 28)
      .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
      .position(x: x, y: 18)
  }

  private func position(for value: Int, width: CGFloat) -> CGFloat {
    let span = max(1, range.upperBound - range.lowerBound)
    let ratio = CGFloat(value - range.lowerBound) / CGFloat(span)
    return min(max(14, ratio * width), width - 14)
  }

  private func valueFor(x: CGFloat, width: CGFloat) -> Int {
    let usable = max(1, width)
    let ratio = min(max(0, x / usable), 1)
    let span = range.upperBound - range.lowerBound
    return Int((Double(range.lowerBound) + Double(ratio) * Double(span)).rounded()).clamped(to: range)
  }
}

private extension CodableColor {
  init(_ color: Color) {
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
      self.init(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    } else {
      self.init(red: 1, green: 1, blue: 1, opacity: 1)
    }
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
