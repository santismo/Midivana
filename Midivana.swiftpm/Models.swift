import Foundation
import SwiftUI

enum PerformanceLayout: String, CaseIterable, Identifiable, Codable {
  case fretboard
  case keyboard
  case drums
  case custom

  var id: String { rawValue }

  var title: String {
    switch self {
    case .fretboard: return "Fretboard"
    case .keyboard: return "Keys"
    case .drums: return "Drums"
    case .custom: return "Custom"
    }
  }

  var systemImage: String {
    switch self {
    case .fretboard: return "rectangle.grid.3x2"
    case .keyboard: return "pianokeys"
    case .drums: return "square.grid.3x3.square"
    case .custom: return "slider.horizontal.3"
    }
  }
}

enum ScaleKind: String, CaseIterable, Identifiable, Codable {
  case chromatic
  case major
  case naturalMinor
  case minorPentatonic
  case blues
  case dorian
  case mixolydian

  var id: String { rawValue }

  var title: String {
    switch self {
    case .chromatic: return "Chromatic"
    case .major: return "Major"
    case .naturalMinor: return "Natural minor"
    case .minorPentatonic: return "Minor pentatonic"
    case .blues: return "Blues"
    case .dorian: return "Dorian"
    case .mixolydian: return "Mixolydian"
    }
  }

  var intervals: Set<Int> {
    switch self {
    case .chromatic: return Set(0..<12)
    case .major: return [0, 2, 4, 5, 7, 9, 11]
    case .naturalMinor: return [0, 2, 3, 5, 7, 8, 10]
    case .minorPentatonic: return [0, 3, 5, 7, 10]
    case .blues: return [0, 3, 5, 6, 7, 10]
    case .dorian: return [0, 2, 3, 5, 7, 9, 10]
    case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
    }
  }
}

enum SustainMode: String, CaseIterable, Identifiable, Codable {
  case momentary
  case hold
  case latch

  var id: String { rawValue }

  var title: String {
    switch self {
    case .momentary: return "Momentary"
    case .hold: return "Hold button"
    case .latch: return "Latch pads"
    }
  }
}

enum VelocityMode: String, CaseIterable, Identifiable, Codable {
  case accelerometer
  case fixed

  var id: String { rawValue }

  var title: String {
    switch self {
    case .accelerometer: return "Accelerometer"
    case .fixed: return "Fixed"
    }
  }
}

enum PadShape: String, CaseIterable, Identifiable, Codable {
  case rounded
  case square
  case circle
  case hex
  case diamond
  case octagon
  case capsule
  case triangle
  case star
  case pentagon
  case spark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .rounded: return "Rounded"
    case .square: return "Square"
    case .circle: return "Circle"
    case .hex: return "Hex"
    case .diamond: return "Diamond"
    case .octagon: return "Octagon"
    case .capsule: return "Pill"
    case .triangle: return "Triangle"
    case .star: return "Star"
    case .pentagon: return "Pentagon"
    case .spark: return "Spark"
    }
  }
}

enum CustomItemKind: String, CaseIterable, Identifiable, Codable {
  case note
  case ccSliderX
  case ccSliderY
  case label
  case sustain
  case panic
  case image
  case video
  case keyCommand

  var id: String { rawValue }

  var title: String {
    switch self {
    case .note: return "Note"
    case .ccSliderX: return "Slider H"
    case .ccSliderY: return "Slider V"
    case .label: return "Label"
    case .sustain: return "Sustain"
    case .panic: return "Panic"
    case .image: return "Image"
    case .video: return "Video"
    case .keyCommand: return "CC Key"
    }
  }
}

enum CustomSliderStyle: String, CaseIterable, Identifiable, Codable {
  case standard
  case spring

  var id: String { rawValue }

  var title: String {
    switch self {
    case .standard: return "Standard"
    case .spring: return "Spring"
    }
  }
}

struct CodableColor: Codable, Equatable, Hashable {
  var red: Double
  var green: Double
  var blue: Double
  var opacity: Double

  var color: Color {
    Color(red: red, green: green, blue: blue).opacity(opacity)
  }

  static let background = CodableColor(hex: 0x08090B)
  static let htmlBackground = CodableColor(hex: 0x000000)
  static let panel = CodableColor(red: 0.04, green: 0.04, blue: 0.04, opacity: 0.78)
  static let pad = CodableColor(hex: 0x0A0A0A)
  static let scalePad = CodableColor(hex: 0x0A0A0A)
  static let active = CodableColor(hex: 0x1A1A1A)
  static let border = CodableColor(red: 1, green: 1, blue: 1, opacity: 0.8)
  static let glow = CodableColor(red: 1, green: 1, blue: 1, opacity: 0.25)
  static let activeGlow = CodableColor(red: 1, green: 1, blue: 1, opacity: 0.7)
  static let amber = CodableColor(hex: 0xFFB94C)
  static let violet = CodableColor(hex: 0x9B7CFF)

  init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
    self.red = red
    self.green = green
    self.blue = blue
    self.opacity = opacity
  }

  init(hex: UInt32, opacity: Double = 1) {
    red = Double((hex >> 16) & 0xFF) / 255
    green = Double((hex >> 8) & 0xFF) / 255
    blue = Double(hex & 0xFF) / 255
    self.opacity = opacity
  }
}

struct ThemeSettings: Codable, Equatable {
  var background = CodableColor.htmlBackground
  var panel = CodableColor.panel
  var pad = CodableColor.pad
  var scalePad = CodableColor.scalePad
  var activePad = CodableColor.active
  var padBorder = CodableColor.border
  var padBorderWidth = 2.5
  var padGlow = CodableColor.glow
  var activeGlow = CodableColor.activeGlow
  var rootBorder = CodableColor.border
  var accent = CodableColor.violet
  var shape = PadShape.circle
  var showNoteNames = false
  var glowOnTouch = true
  var scaleOnTouch = true
  var pulseGlow = true
  var hueShift = false
  var hueShiftAmount = 360.0
  var hueShiftSpeed = 10.0
  var huePadAmount = 180.0
  var hueBackgroundDrift = 0.35
  var hueBlendIntensity = 0.45
  var colorMode = "custom"
  var gradientTop = CodableColor(hex: 0x6EE6FF)
  var gradientBottom = CodableColor(hex: 0xFFB36A)
  var markerMode = "edges"
  var markerShape = "dot"
  var markerOffset = -80.0
  var markerColor = CodableColor(red: 1, green: 1, blue: 1, opacity: 0.7)
  var rowGap = 7.0
  var padGap = 8.0
  var controlFill = "solid"
  var padFillMode = "solid"
}

struct CustomItem: Identifiable, Codable, Equatable {
  var id = UUID()
  var kind = CustomItemKind.note
  var label = "Pad"
  var note = 60
  var channel = 1
  var cc = 1
  var value = 64
  var x = 0.08
  var y = 0.08
  var width = 0.18
  var height = 0.18
  var shape = PadShape.rounded
  var fill = CodableColor.pad
  var activeFill = CodableColor.active
  var imageData: Data?
  var activeImageData: Data?
  var videoData: Data?
  var keyCommand = "ArrowLeft"
  var labelSize = 64.0
  var rotation = 0.0
  // Optional so existing layouts and presets continue to decode as the standard slider.
  var sliderStyle: CustomSliderStyle?
}

struct MacKeyPad: Identifiable, Codable, Equatable {
  var id: UUID
  var label: String
  var cc: Int
  var pressValue: Int
  var x: Double
  var y: Double
  var width: Double
  var height: Double

  init(
    id: UUID = UUID(),
    label: String = "Key",
    cc: Int = 80,
    pressValue: Int = 127,
    x: Double = 0.04,
    y: Double = 0.18,
    width: Double = 0.16,
    height: Double = 0.64
  ) {
    self.id = id
    self.label = label
    self.cc = cc
    self.pressValue = pressValue
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case label
    case cc
    case pressValue
    case x
    case y
    case width
    case height
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    label = try container.decodeIfPresent(String.self, forKey: .label) ?? "Key"
    cc = try container.decodeIfPresent(Int.self, forKey: .cc) ?? 80
    pressValue = try container.decodeIfPresent(Int.self, forKey: .pressValue) ?? 127
    x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 0.04
    y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 0.18
    width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 0.16
    height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 0.64
    self = normalized
  }

  var normalized: MacKeyPad {
    var copy = self
    copy.label = copy.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Key" : copy.label
    copy.cc = min(max(0, copy.cc), 127)
    copy.pressValue = min(max(1, copy.pressValue), 127)
    copy.width = min(max(0.06, copy.width), 1)
    copy.height = min(max(0.12, copy.height), 1)
    copy.x = min(max(0, copy.x), 1 - copy.width)
    copy.y = min(max(0, copy.y), 1 - copy.height)
    return copy
  }

  static func defaultRow(
    leftCC: Int = 80,
    rightCC: Int = 81,
    downCC: Int = 83,
    upCC: Int = 82,
    iCC: Int = 84,
    pressValue: Int = 127
  ) -> [MacKeyPad] {
    let width = 0.16
    let gap = 0.035
    let startX = 0.05
    let y = 0.2
    let height = 0.6
    let entries: [(String, Int)] = [
      ("←", leftCC),
      ("→", rightCC),
      ("↓", downCC),
      ("↑", upCC),
      ("i", iCC)
    ]
    return entries.enumerated().map { index, entry in
      MacKeyPad(
        label: entry.0,
        cc: entry.1,
        pressValue: pressValue,
        x: startX + Double(index) * (width + gap),
        y: y,
        width: width,
        height: height
      ).normalized
    }
  }
}

struct CustomSnapGrid: Codable, Equatable {
  var x = 0.0
  var y = 0.0
  var width = 1.0
  var height = 1.0

  var normalized: CustomSnapGrid {
    let nextWidth = min(max(0.05, width), 1)
    let nextHeight = min(max(0.05, height), 1)
    return CustomSnapGrid(
      x: min(max(0, x), 1 - nextWidth),
      y: min(max(0, y), 1 - nextHeight),
      width: nextWidth,
      height: nextHeight
    )
  }
}

struct CustomLayout: Identifiable, Codable, Equatable {
  var id = UUID()
  var name = "Custom Layout"
  var snapToGrid = true
  var gridColumns = 12
  var gridRows = 8
  var snapGrid: CustomSnapGrid?
  var flipHorizontal = false
  var showLabels = true
  var items: [CustomItem] = []

  init(
    id: UUID = UUID(),
    name: String = "Custom Layout",
    snapToGrid: Bool = true,
    gridColumns: Int = 12,
    gridRows: Int = 8,
    snapGrid: CustomSnapGrid? = nil,
    flipHorizontal: Bool = false,
    showLabels: Bool = true,
    items: [CustomItem] = []
  ) {
    self.id = id
    self.name = name
    self.snapToGrid = snapToGrid
    self.gridColumns = gridColumns
    self.gridRows = gridRows
    self.snapGrid = snapGrid
    self.flipHorizontal = flipHorizontal
    self.showLabels = showLabels
    self.items = items
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case snapToGrid
    case gridColumns
    case gridRows
    case snapGrid
    case flipHorizontal
    case showLabels
    case items
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Custom Layout"
    snapToGrid = try container.decodeIfPresent(Bool.self, forKey: .snapToGrid) ?? true
    gridColumns = try container.decodeIfPresent(Int.self, forKey: .gridColumns) ?? 12
    gridRows = try container.decodeIfPresent(Int.self, forKey: .gridRows) ?? 8
    snapGrid = try container.decodeIfPresent(CustomSnapGrid.self, forKey: .snapGrid)
    flipHorizontal = try container.decodeIfPresent(Bool.self, forKey: .flipHorizontal) ?? false
    showLabels = try container.decodeIfPresent(Bool.self, forKey: .showLabels) ?? true
    items = try container.decodeIfPresent([CustomItem].self, forKey: .items) ?? []
  }

  static var fretsAndSliders: CustomLayout {
    var layout = CustomLayout(name: "Frets + sliders")
    layout.items = [
      CustomItem(kind: .ccSliderX, label: "CC 1", cc: 1, x: 0.08, y: 0.08, width: 0.36, height: 0.12, fill: .violet),
      CustomItem(kind: .ccSliderX, label: "CC 74", cc: 74, x: 0.56, y: 0.08, width: 0.36, height: 0.12, fill: .amber),
      CustomItem(kind: .sustain, label: "Sustain", note: 0, x: 0.08, y: 0.78, width: 0.18, height: 0.13, fill: CodableColor(hex: 0x26313A)),
      CustomItem(kind: .panic, label: "Panic", note: 0, x: 0.74, y: 0.78, width: 0.18, height: 0.13, fill: CodableColor(hex: 0x642828))
    ]
    let notes = [60, 62, 63, 65, 67, 70, 72, 74]
    for (index, note) in notes.enumerated() {
      let col = Double(index % 4)
      let row = Double(index / 4)
      layout.items.append(CustomItem(
        kind: .note,
        label: MusicTheory.noteName(note),
        note: note,
        x: 0.16 + col * 0.18,
        y: 0.28 + row * 0.22,
        width: 0.13,
        height: 0.16,
        fill: CodableColor(hex: 0x1A2D2B)
      ))
    }
    return layout
  }

  static var blankGrid: CustomLayout {
    CustomLayout(
      name: "Blank Grid",
      snapToGrid: true,
      gridColumns: 12,
      gridRows: 8,
      snapGrid: CustomSnapGrid(x: 0, y: 0, width: 1, height: 1),
      items: []
    )
  }

  static var editableFretboard: CustomLayout {
    var layout = CustomLayout(name: "Editable Fretboard", snapToGrid: true, gridColumns: 13, gridRows: 5)
    let fretCount = 13
    let strings = MusicTheory.guitarTuningHighToLow
    let width = 0.9 / Double(fretCount)
    let height = 0.095
    let startX = 0.05
    let startY = 0.16
    let rowGap = 0.012
    layout.snapGrid = CustomSnapGrid(
      x: startX,
      y: startY,
      width: 0.9,
      height: Double(strings.count - 1) * (height + rowGap)
    )
    for (row, openNote) in strings.enumerated() {
      for fret in 0..<fretCount {
        let note = openNote + fret
        layout.items.append(CustomItem(
          kind: .note,
          label: fret == 0 ? "0" : "\(fret)",
          note: note,
          channel: max(1, 6 - row),
          x: startX + Double(fret) * width,
          y: startY + Double(row) * (height + rowGap),
          width: width * 0.9,
          height: height,
          shape: .circle,
          fill: CodableColor.pad
        ))
      }
    }
    layout.items.append(CustomItem(kind: .sustain, label: "Sustain", note: 0, x: 0.08, y: 0.84, width: 0.32, height: 0.12, fill: CodableColor(hex: 0x26313A)))
    layout.items.append(CustomItem(kind: .panic, label: "Panic", note: 0, x: 0.72, y: 0.84, width: 0.2, height: 0.12, fill: CodableColor(hex: 0x642828)))
    return layout
  }

  static var editableDrumset: CustomLayout {
    var layout = CustomLayout(name: "Editable Drumset", snapToGrid: true, gridColumns: 12, gridRows: 8)
    let items: [CustomItem] = [
      CustomItem(kind: .note, label: "Crash", note: 49, channel: 10, x: 0.04, y: 0.06, width: 0.22, height: 0.12, shape: .capsule, fill: CodableColor(hex: 0x23202E)),
      CustomItem(kind: .note, label: "Ride", note: 51, channel: 10, x: 0.28, y: 0.06, width: 0.22, height: 0.12, shape: .capsule, fill: CodableColor(hex: 0x23202E)),
      CustomItem(kind: .note, label: "Crash 2", note: 57, channel: 10, x: 0.52, y: 0.06, width: 0.22, height: 0.12, shape: .capsule, fill: CodableColor(hex: 0x23202E)),
      CustomItem(kind: .note, label: "Splash", note: 55, channel: 10, x: 0.76, y: 0.06, width: 0.2, height: 0.12, shape: .capsule, fill: CodableColor(hex: 0x23202E)),
      CustomItem(kind: .note, label: "Open Hat", note: 46, channel: 10, x: 0.04, y: 0.23, width: 0.22, height: 0.12, shape: .capsule, fill: CodableColor(hex: 0x20302F)),
      CustomItem(kind: .note, label: "Hat", note: 42, channel: 10, x: 0.04, y: 0.38, width: 0.22, height: 0.12, shape: .capsule, fill: CodableColor(hex: 0x20302F)),
      CustomItem(kind: .note, label: "Tom 1", note: 50, channel: 10, x: 0.31, y: 0.25, width: 0.18, height: 0.18, shape: .circle, fill: CodableColor(hex: 0x211C2A)),
      CustomItem(kind: .note, label: "Tom 2", note: 47, channel: 10, x: 0.51, y: 0.25, width: 0.18, height: 0.18, shape: .circle, fill: CodableColor(hex: 0x211C2A)),
      CustomItem(kind: .note, label: "Tom 3", note: 45, channel: 10, x: 0.71, y: 0.25, width: 0.18, height: 0.18, shape: .circle, fill: CodableColor(hex: 0x211C2A)),
      CustomItem(kind: .note, label: "Tom 4", note: 43, channel: 10, x: 0.3, y: 0.48, width: 0.2, height: 0.18, shape: .circle, fill: CodableColor(hex: 0x211C2A)),
      CustomItem(kind: .note, label: "Tom 5", note: 41, channel: 10, x: 0.53, y: 0.48, width: 0.2, height: 0.18, shape: .circle, fill: CodableColor(hex: 0x211C2A)),
      CustomItem(kind: .note, label: "Rim", note: 37, channel: 10, x: 0.05, y: 0.65, width: 0.14, height: 0.12, shape: .rounded, fill: CodableColor(hex: 0x2F2424)),
      CustomItem(kind: .note, label: "Snare", note: 38, channel: 10, x: 0.22, y: 0.64, width: 0.26, height: 0.16, shape: .circle, fill: CodableColor(hex: 0x30242A)),
      CustomItem(kind: .note, label: "Kick", note: 36, channel: 10, x: 0.36, y: 0.76, width: 0.42, height: 0.18, shape: .circle, fill: CodableColor(hex: 0x322818))
    ]
    layout.items = items
    return layout
  }
}

struct AppPreset: Identifiable, Codable, Equatable {
  var id = UUID()
  var name = "Default"
  var layout = PerformanceLayout.fretboard
  var rootNote = 0
  var baseOctave = 4
  var midiChannel = 1
  var velocity = 104
  var velocityMode = VelocityMode.accelerometer
  var velocityMin = 1
  var velocityMax = 127
  var velocityCurve = "soft"
  var accelSensitivity = 2.0
  var touchForceSensitivity = 0.0
  var accelFloor = 0.0
  var accelMax = 1.0
  var scale = ScaleKind.minorPentatonic
  var sustainMode = SustainMode.hold
  var motionToCC = false
  var motionCC = 1
  var cc1Visible = true
  var cc1Number = 1
  var cc2Visible = false
  var cc2Number = 74
  var quickCCNumbers = [1]
  var quickCCVisibleCount = 1
  var pitchBendEnabled = false
  var pitchBendRange = 12
  var vibratoEnabled = false
  var vibratoRate = 6.0
  var vibratoDepth = 0.2
  var showMacKeyPads = true
  var keyPadPressValue = 127
  var keyPadCCLeft = 80
  var keyPadCCRight = 81
  var keyPadCCUp = 82
  var keyPadCCDown = 83
  var keyPadCCI = 84
  var keyPadEditMode = false
  var keyPads = MacKeyPad.defaultRow()
  var fretCount = 13
  var keyboardOctaves = 2
  var keyboardRows = 2
  var drumColumns = 12
  var drumRows = 6
  var drumTomCount = 6
  var drumCymbalCount = 4
  var drumTomRows = 2
  var drumCymbalRows = 1
  var drumFlip = true
  var drumMap = MusicTheory.defaultDrumNotes
  var stringTunings = MusicTheory.guitarTuningHighToLow
  var stringChannels = [6, 5, 4, 3, 2, 1]
  var theme = ThemeSettings()
  var customLayout = CustomLayout.editableFretboard

  init() {}

  init(from decoder: Decoder) throws {
    let defaults = AppPreset()
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? defaults.id
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? defaults.name
    layout = try container.decodeIfPresent(PerformanceLayout.self, forKey: .layout) ?? defaults.layout
    rootNote = try container.decodeIfPresent(Int.self, forKey: .rootNote) ?? defaults.rootNote
    baseOctave = try container.decodeIfPresent(Int.self, forKey: .baseOctave) ?? defaults.baseOctave
    midiChannel = try container.decodeIfPresent(Int.self, forKey: .midiChannel) ?? defaults.midiChannel
    velocity = try container.decodeIfPresent(Int.self, forKey: .velocity) ?? defaults.velocity
    velocityMode = try container.decodeIfPresent(VelocityMode.self, forKey: .velocityMode) ?? defaults.velocityMode
    velocityMin = try container.decodeIfPresent(Int.self, forKey: .velocityMin) ?? defaults.velocityMin
    velocityMax = try container.decodeIfPresent(Int.self, forKey: .velocityMax) ?? defaults.velocityMax
    velocityCurve = try container.decodeIfPresent(String.self, forKey: .velocityCurve) ?? defaults.velocityCurve
    accelSensitivity = try container.decodeIfPresent(Double.self, forKey: .accelSensitivity) ?? defaults.accelSensitivity
    touchForceSensitivity = try container.decodeIfPresent(Double.self, forKey: .touchForceSensitivity) ?? defaults.touchForceSensitivity
    accelFloor = try container.decodeIfPresent(Double.self, forKey: .accelFloor) ?? defaults.accelFloor
    accelMax = try container.decodeIfPresent(Double.self, forKey: .accelMax) ?? defaults.accelMax
    scale = try container.decodeIfPresent(ScaleKind.self, forKey: .scale) ?? defaults.scale
    sustainMode = try container.decodeIfPresent(SustainMode.self, forKey: .sustainMode) ?? defaults.sustainMode
    motionToCC = try container.decodeIfPresent(Bool.self, forKey: .motionToCC) ?? defaults.motionToCC
    motionCC = try container.decodeIfPresent(Int.self, forKey: .motionCC) ?? defaults.motionCC
    cc1Visible = try container.decodeIfPresent(Bool.self, forKey: .cc1Visible) ?? defaults.cc1Visible
    cc1Number = try container.decodeIfPresent(Int.self, forKey: .cc1Number) ?? defaults.cc1Number
    cc2Visible = try container.decodeIfPresent(Bool.self, forKey: .cc2Visible) ?? defaults.cc2Visible
    cc2Number = try container.decodeIfPresent(Int.self, forKey: .cc2Number) ?? defaults.cc2Number
    quickCCNumbers = try container.decodeIfPresent([Int].self, forKey: .quickCCNumbers) ?? defaults.quickCCNumbers
    quickCCVisibleCount = try container.decodeIfPresent(Int.self, forKey: .quickCCVisibleCount) ?? defaults.quickCCVisibleCount
    pitchBendEnabled = try container.decodeIfPresent(Bool.self, forKey: .pitchBendEnabled) ?? defaults.pitchBendEnabled
    pitchBendRange = try container.decodeIfPresent(Int.self, forKey: .pitchBendRange) ?? defaults.pitchBendRange
    vibratoEnabled = try container.decodeIfPresent(Bool.self, forKey: .vibratoEnabled) ?? defaults.vibratoEnabled
    vibratoRate = try container.decodeIfPresent(Double.self, forKey: .vibratoRate) ?? defaults.vibratoRate
    vibratoDepth = try container.decodeIfPresent(Double.self, forKey: .vibratoDepth) ?? defaults.vibratoDepth
    showMacKeyPads = try container.decodeIfPresent(Bool.self, forKey: .showMacKeyPads) ?? defaults.showMacKeyPads
    keyPadPressValue = try container.decodeIfPresent(Int.self, forKey: .keyPadPressValue) ?? defaults.keyPadPressValue
    keyPadCCLeft = try container.decodeIfPresent(Int.self, forKey: .keyPadCCLeft) ?? defaults.keyPadCCLeft
    keyPadCCRight = try container.decodeIfPresent(Int.self, forKey: .keyPadCCRight) ?? defaults.keyPadCCRight
    keyPadCCUp = try container.decodeIfPresent(Int.self, forKey: .keyPadCCUp) ?? defaults.keyPadCCUp
    keyPadCCDown = try container.decodeIfPresent(Int.self, forKey: .keyPadCCDown) ?? defaults.keyPadCCDown
    keyPadCCI = try container.decodeIfPresent(Int.self, forKey: .keyPadCCI) ?? defaults.keyPadCCI
    keyPadEditMode = try container.decodeIfPresent(Bool.self, forKey: .keyPadEditMode) ?? defaults.keyPadEditMode
    let decodedKeyPads = try container.decodeIfPresent([MacKeyPad].self, forKey: .keyPads) ?? []
    keyPads = decodedKeyPads.isEmpty
      ? MacKeyPad.defaultRow(
        leftCC: keyPadCCLeft,
        rightCC: keyPadCCRight,
        downCC: keyPadCCDown,
        upCC: keyPadCCUp,
        iCC: keyPadCCI,
        pressValue: keyPadPressValue
      )
      : decodedKeyPads.map(\.normalized)
    fretCount = try container.decodeIfPresent(Int.self, forKey: .fretCount) ?? defaults.fretCount
    keyboardOctaves = try container.decodeIfPresent(Int.self, forKey: .keyboardOctaves) ?? defaults.keyboardOctaves
    keyboardRows = try container.decodeIfPresent(Int.self, forKey: .keyboardRows) ?? defaults.keyboardRows
    drumColumns = try container.decodeIfPresent(Int.self, forKey: .drumColumns) ?? defaults.drumColumns
    drumRows = try container.decodeIfPresent(Int.self, forKey: .drumRows) ?? defaults.drumRows
    drumTomCount = try container.decodeIfPresent(Int.self, forKey: .drumTomCount) ?? defaults.drumTomCount
    drumCymbalCount = try container.decodeIfPresent(Int.self, forKey: .drumCymbalCount) ?? defaults.drumCymbalCount
    drumTomRows = try container.decodeIfPresent(Int.self, forKey: .drumTomRows) ?? defaults.drumTomRows
    drumCymbalRows = try container.decodeIfPresent(Int.self, forKey: .drumCymbalRows) ?? defaults.drumCymbalRows
    drumFlip = try container.decodeIfPresent(Bool.self, forKey: .drumFlip) ?? defaults.drumFlip
    drumMap = try container.decodeIfPresent([Int].self, forKey: .drumMap) ?? defaults.drumMap
    stringTunings = try container.decodeIfPresent([Int].self, forKey: .stringTunings) ?? defaults.stringTunings
    stringChannels = try container.decodeIfPresent([Int].self, forKey: .stringChannels) ?? defaults.stringChannels
    theme = try container.decodeIfPresent(ThemeSettings.self, forKey: .theme) ?? defaults.theme
    customLayout = try container.decodeIfPresent(CustomLayout.self, forKey: .customLayout) ?? defaults.customLayout
  }

  static let `default` = AppPreset()
}

struct NotePad: Identifiable, Hashable {
  let id: String
  let note: Int
  let title: String
  let subtitle: String
  let row: Int
  let column: Int
  let channel: Int
  let isInScale: Bool
}

struct ActiveNote: Hashable, Codable {
  let note: Int
  let channel: Int
}

struct ActiveControl: Hashable, Codable {
  let controller: Int
  let channel: Int
}

struct MIDIEndpointInfo: Identifiable, Equatable {
  let id: Int32
  let name: String
}
