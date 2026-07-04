import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PhotosUI
import AVKit

private struct MidivanaHueAngleKey: EnvironmentKey {
  static let defaultValue = Angle.zero
}

private struct MidivanaPadHueAmountKey: EnvironmentKey {
  static let defaultValue = 360.0
}

private struct MidivanaPadBorderWidthKey: EnvironmentKey {
  static let defaultValue = 2.5
}

private extension EnvironmentValues {
  var midivanaHueAngle: Angle {
    get { self[MidivanaHueAngleKey.self] }
    set { self[MidivanaHueAngleKey.self] = newValue }
  }

  var midivanaPadHueAmount: Double {
    get { self[MidivanaPadHueAmountKey.self] }
    set { self[MidivanaPadHueAmountKey.self] = newValue }
  }

  var midivanaPadBorderWidth: Double {
    get { self[MidivanaPadBorderWidthKey.self] }
    set { self[MidivanaPadBorderWidthKey.self] = newValue }
  }
}

struct ContentView: View {
  @StateObject private var app = AppModel()
  @State private var showingSettings = false
  @State private var showingMacKeys = false
  @State private var showingNoteRepeat = false
  @State private var settingsOffset = CGSize(width: -18, height: 86)
  @State private var keyPadPanelOffset = CGSize.zero
  @State private var keyPadPanelSize = CGSize(width: 430, height: 168)
  @State private var hueStartDate = Date()

  var body: some View {
    GeometryReader { rootProxy in
      ZStack(alignment: .topTrailing) {
        let keyPadSize = clampedKeyPadPanelSize(keyPadPanelSize, rootSize: rootProxy.size)

        TimelineView(.animation) { timeline in
          let hueAngle = app.preset.theme.hueShift ? hueAngle(for: timeline.date) : .zero
          ZStack {
            AnimatedBackground(app: app, hueAngle: hueAngle)
              .ignoresSafeArea()

            VStack(spacing: 12) {
              TopBar(app: app, showingSettings: $showingSettings, showingMacKeys: $showingMacKeys, showingNoteRepeat: $showingNoteRepeat)
              PerformanceSurface(app: app)
            }
            .padding(.horizontal, app.preset.layout == .custom ? 2 : 18)
            .padding(.vertical, app.preset.layout == .custom ? 8 : 14)
            .foregroundStyle(.white)
            .environment(\.midivanaHueAngle, app.preset.theme.hueShift ? hueAngle : .zero)
            .environment(\.midivanaPadHueAmount, app.preset.theme.huePadAmount)
            .environment(\.midivanaPadBorderWidth, app.preset.theme.padBorderWidth)
          }
        }

        if showingMacKeys {
          TouchKeyPadPanel(
            app: app,
            close: {
              showingMacKeys = false
              app.releaseAll()
            },
            moveBy: { delta in
              let next = CGSize(
                width: keyPadPanelOffset.width + delta.width,
                height: keyPadPanelOffset.height + delta.height
              )
              keyPadPanelOffset = clampedKeyPadPanelOffset(next, panelSize: keyPadSize, rootSize: rootProxy.size)
            },
            resizeBy: { delta in
              let nextSize = CGSize(
                width: keyPadPanelSize.width + delta.width,
                height: keyPadPanelSize.height + delta.height
              )
              let clampedSize = clampedKeyPadPanelSize(nextSize, rootSize: rootProxy.size)
              let realizedWidthDelta = clampedSize.width - keyPadPanelSize.width
              keyPadPanelSize = clampedSize
              let nextOffset = CGSize(
                width: keyPadPanelOffset.width + realizedWidthDelta,
                height: keyPadPanelOffset.height
              )
              keyPadPanelOffset = clampedKeyPadPanelOffset(nextOffset, panelSize: clampedSize, rootSize: rootProxy.size)
            }
          )
            .frame(width: keyPadSize.width, height: keyPadSize.height)
            .padding(.top, keyPadPanelBaseTop)
            .padding(.trailing, keyPadPanelBaseTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(keyPadPanelOffset)
            .zIndex(200)
            .transaction { transaction in
              transaction.animation = nil
            }
        }

        if showingNoteRepeat {
          NoteRepeatWindow(app: app, visible: $showingNoteRepeat)
            .padding(.top, 90)
            .padding(.trailing, 258)
            .zIndex(70)
            .transaction { transaction in
              transaction.animation = nil
            }
        }

        if showingSettings {
          FloatingSettingsWindow(app: app, visible: $showingSettings, offset: $settingsOffset)
            .zIndex(80)
            .transaction { transaction in
              transaction.animation = nil
            }
        }
      }
      .frame(width: rootProxy.size.width, height: rootProxy.size.height)
      .coordinateSpace(name: "MidivanaRoot")
    }
    .onAppear {
      app.refreshMIDI()
    }
    .onChange(of: app.preset.showMacKeyPads) { _, enabled in
      if !enabled {
        showingMacKeys = false
      }
    }
    .onChange(of: app.preset.showNoteRepeatControls) { _, enabled in
      if !enabled {
        showingNoteRepeat = false
      }
    }
    .onDisappear {
      app.releaseAll()
    }
  }

  private func hueAngle(for date: Date) -> Angle {
    let secondsPerCycle = max(0.5, app.preset.theme.hueShiftSpeed)
    let degreesPerSecond = app.preset.theme.hueShiftAmount / secondsPerCycle
    let degrees = date.timeIntervalSince(hueStartDate) * degreesPerSecond
    return .degrees(degrees)
  }

  private let keyPadPanelBaseTop: CGFloat = 84
  private let keyPadPanelBaseTrailing: CGFloat = 96

  private func clampedKeyPadPanelSize(_ size: CGSize, rootSize: CGSize) -> CGSize {
    CGSize(
      width: min(max(280, size.width), max(280, rootSize.width - 32)),
      height: min(max(126, size.height), max(126, rootSize.height - 32))
    )
  }

  private func clampedKeyPadPanelOffset(_ offset: CGSize, panelSize: CGSize, rootSize: CGSize) -> CGSize {
    let baseLeft = rootSize.width - panelSize.width - keyPadPanelBaseTrailing
    let minX = 16 - baseLeft
    let maxX = keyPadPanelBaseTrailing - 16
    let minY = 16 - keyPadPanelBaseTop
    let maxY = rootSize.height - 16 - panelSize.height - keyPadPanelBaseTop
    return CGSize(
      width: min(max(minX, offset.width), maxX),
      height: min(max(minY, offset.height), maxY)
    )
  }
}

private struct TouchKeyPadPanel: UIViewRepresentable {
  @ObservedObject var app: AppModel
  let close: () -> Void
  let moveBy: (CGSize) -> Void
  let resizeBy: (CGSize) -> Void

  func makeUIView(context: Context) -> PanelView {
    let view = PanelView()
    view.isMultipleTouchEnabled = true
    view.backgroundColor = .clear
    view.app = app
    view.close = close
    view.moveBy = moveBy
    view.resizeBy = resizeBy
    return view
  }

  func updateUIView(_ uiView: PanelView, context: Context) {
    uiView.app = app
    uiView.close = close
    uiView.moveBy = moveBy
    uiView.resizeBy = resizeBy
    uiView.setNeedsDisplay()
  }

  final class PanelView: UIView {
    weak var app: AppModel?
    var close: (() -> Void)?
    var moveBy: ((CGSize) -> Void)?
    var resizeBy: ((CGSize) -> Void)?
    private var activePads: [ObjectIdentifier: MacKeyPad] = [:]
    private var dragTouchID: ObjectIdentifier?
    private var lastDragPoint: CGPoint?
    private var resizeTouchID: ObjectIdentifier?
    private var lastResizePoint: CGPoint?
    private let inset: CGFloat = 8
    private let headerHeight: CGFloat = 34

    override func draw(_ rect: CGRect) {
      super.draw(rect)
      guard let app else { return }
      uiColor(app.preset.theme.panel, alphaMultiplier: 0.94).setFill()
      UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: 12).fill()
      drawHeader(theme: app.preset.theme)
      drawKeys(app: app)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      begin(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      move(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window == nil {
        releaseAllTouches()
      }
    }

    private var closeRect: CGRect {
      CGRect(x: bounds.maxX - 42, y: 5, width: 34, height: 26)
    }

    private var dragHandleRect: CGRect {
      CGRect(x: inset, y: 0, width: max(80, bounds.width - inset * 2 - 52), height: headerHeight)
    }

    private var resizeRect: CGRect {
      CGRect(x: bounds.maxX - 36, y: bounds.maxY - 36, width: 32, height: 32)
    }

    private var keyArea: CGRect {
      CGRect(
        x: inset,
        y: headerHeight,
        width: max(1, bounds.width - inset * 2),
        height: max(1, bounds.height - headerHeight - inset)
      )
    }

    private func begin(_ touches: Set<UITouch>) {
      guard let app else { return }
      var changed = false
      for touch in touches {
        let touchID = ObjectIdentifier(touch)
        let point = touch.location(in: self)
        if closeRect.contains(point) {
          releaseAllTouches()
          close?()
          return
        }
        if resizeRect.contains(point) {
          resizeTouchID = touchID
          lastResizePoint = touch.location(in: superview)
          continue
        }
        if dragHandleRect.contains(point) {
          dragTouchID = touchID
          lastDragPoint = touch.location(in: superview)
          continue
        }
        guard !app.preset.keyPadEditMode, let pad = pad(at: point) else {
          if let previous = activePads.removeValue(forKey: touchID) {
            app.endKeyPad(previous)
            changed = true
          }
          continue
        }
        if activePads[touchID]?.id == pad.id { continue }
        if let previous = activePads[touchID] {
          app.endKeyPad(previous)
        }
        activePads[touchID] = pad
        app.beginKeyPad(pad)
        changed = true
      }
      if changed {
        setNeedsDisplay()
      }
    }

    private func move(_ touches: Set<UITouch>) {
      guard let app else { return }
      var changed = false
      for touch in touches {
        let touchID = ObjectIdentifier(touch)
        let point = touch.location(in: self)
        if resizeTouchID == touchID {
          let nextPoint = touch.location(in: superview)
          if let lastResizePoint {
            resizeBy?(CGSize(width: nextPoint.x - lastResizePoint.x, height: nextPoint.y - lastResizePoint.y))
          }
          lastResizePoint = nextPoint
          continue
        }
        if dragTouchID == touchID {
          let nextPoint = touch.location(in: superview)
          if let lastDragPoint {
            moveBy?(CGSize(width: nextPoint.x - lastDragPoint.x, height: nextPoint.y - lastDragPoint.y))
          }
          lastDragPoint = nextPoint
          continue
        }
        guard !app.preset.keyPadEditMode, let pad = pad(at: point) else {
          if let previous = activePads.removeValue(forKey: touchID) {
            app.endKeyPad(previous)
            changed = true
          }
          continue
        }
        if activePads[touchID]?.id == pad.id { continue }
        if let previous = activePads[touchID] {
          app.endKeyPad(previous)
        }
        activePads[touchID] = pad
        app.beginKeyPad(pad)
        changed = true
      }
      if changed {
        setNeedsDisplay()
      }
    }

    private func release(_ touches: Set<UITouch>) {
      guard let app else { return }
      var changed = false
      for touch in touches {
        let touchID = ObjectIdentifier(touch)
        if resizeTouchID == touchID {
          resizeTouchID = nil
          lastResizePoint = nil
          continue
        }
        if dragTouchID == touchID {
          dragTouchID = nil
          lastDragPoint = nil
          continue
        }
        if let previous = activePads.removeValue(forKey: touchID) {
          app.endKeyPad(previous)
          changed = true
        }
      }
      if changed {
        setNeedsDisplay()
      }
    }

    private func releaseAllTouches() {
      guard let app else {
        activePads.removeAll()
        return
      }
      let active = activePads.values
      activePads.removeAll()
      dragTouchID = nil
      lastDragPoint = nil
      resizeTouchID = nil
      lastResizePoint = nil
      for pad in active {
        app.endKeyPad(pad)
      }
      setNeedsDisplay()
    }

    private func drawHeader(theme: ThemeSettings) {
      let handle = CGRect(x: inset + 4, y: 15, width: 58, height: 6)
      UIColor.white.withAlphaComponent(0.36).setFill()
      UIBezierPath(roundedRect: handle, cornerRadius: 3).fill()

      let closePath = UIBezierPath(roundedRect: closeRect, cornerRadius: 7)
      UIColor.white.withAlphaComponent(0.16).setFill()
      closePath.fill()
      UIColor.white.withAlphaComponent(0.82).setStroke()
      let xPath = UIBezierPath()
      xPath.move(to: CGPoint(x: closeRect.midX - 5, y: closeRect.midY - 5))
      xPath.addLine(to: CGPoint(x: closeRect.midX + 5, y: closeRect.midY + 5))
      xPath.move(to: CGPoint(x: closeRect.midX + 5, y: closeRect.midY - 5))
      xPath.addLine(to: CGPoint(x: closeRect.midX - 5, y: closeRect.midY + 5))
      xPath.lineWidth = 2
      xPath.stroke()

      let resizePath = UIBezierPath()
      UIColor.white.withAlphaComponent(0.66).setStroke()
      resizePath.move(to: CGPoint(x: resizeRect.maxX - 7, y: resizeRect.minY + 9))
      resizePath.addLine(to: CGPoint(x: resizeRect.maxX - 7, y: resizeRect.maxY - 7))
      resizePath.addLine(to: CGPoint(x: resizeRect.minX + 9, y: resizeRect.maxY - 7))
      resizePath.move(to: CGPoint(x: resizeRect.maxX - 14, y: resizeRect.maxY - 7))
      resizePath.addLine(to: CGPoint(x: resizeRect.maxX - 7, y: resizeRect.maxY - 14))
      resizePath.lineWidth = 2
      resizePath.stroke()
    }

    private func drawKeys(app: AppModel) {
      let activeIDs = Set(activePads.values.map(\.id)).union(app.activeKeyPadIDs)
      for pad in app.preset.keyPads.map(\.normalized) {
        draw(pad: pad, theme: app.preset.theme, active: activeIDs.contains(pad.id))
      }
    }

    private func draw(pad: MacKeyPad, theme: ThemeSettings, active: Bool) {
      let frame = frame(for: pad)
      let path = UIBezierPath(roundedRect: frame, cornerRadius: 8)
      let fill = active ? highlightedColor(theme: theme) : uiColor(theme.panel, alphaMultiplier: 0.82)
      fill.setFill()
      path.fill()
      uiColor(active ? theme.activeGlow : theme.padBorder, alphaMultiplier: active ? 0.86 : 0.48).setStroke()
      path.lineWidth = active ? 2 : 1
      path.stroke()

      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      let fontSize = min(24, max(12, frame.height * 0.4))
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: fontSize),
        .foregroundColor: UIColor.white,
        .paragraphStyle: paragraph
      ]
      let textRect = CGRect(
        x: frame.minX + 4,
        y: frame.midY - (fontSize + 6) / 2,
        width: max(0, frame.width - 8),
        height: fontSize + 6
      )
      NSString(string: pad.label).draw(in: textRect, withAttributes: attributes)
    }

    private func pad(at point: CGPoint) -> MacKeyPad? {
      app?.preset.keyPads.map(\.normalized).reversed().first { frame(for: $0).contains(point) }
    }

    private func frame(for pad: MacKeyPad) -> CGRect {
      let normalized = pad.normalized
      let area = keyArea
      return CGRect(
        x: area.minX + area.width * CGFloat(normalized.x),
        y: area.minY + area.height * CGFloat(normalized.y),
        width: max(34, area.width * CGFloat(normalized.width)),
        height: max(34, area.height * CGFloat(normalized.height))
      )
    }

    private func uiColor(_ color: CodableColor, alphaMultiplier: CGFloat = 1) -> UIColor {
      UIColor(
        red: CGFloat(color.red),
        green: CGFloat(color.green),
        blue: CGFloat(color.blue),
        alpha: CGFloat(color.opacity) * alphaMultiplier
      )
    }

    private func highlightedColor(theme: ThemeSettings) -> UIColor {
      uiColor(theme.activeGlow, alphaMultiplier: 0.9)
        .withAlphaComponent(max(0.72, CGFloat(theme.activeGlow.opacity)))
    }
  }
}

private struct FloatingSettingsWindow: View {
  @ObservedObject var app: AppModel
  @Binding var visible: Bool
  @Binding var offset: CGSize
  @State private var dragStart: CGSize?
  @State private var size = CGSize(width: 430, height: 520)
  @State private var resizeStart: CGSize?

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      VStack(spacing: 0) {
        HStack(spacing: 8) {
          Capsule()
            .fill(Color.white.opacity(0.38))
            .frame(width: 30, height: 4)
          Text("Settings")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Button {
            visible = false
          } label: {
            Image(systemName: "xmark")
              .font(.caption.weight(.bold))
              .frame(width: 28, height: 24)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(app.preset.theme.panel.color.opacity(0.98))
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .named("MidivanaRoot"))
            .onChanged { value in
              if dragStart == nil { dragStart = offset }
              guard let dragStart else { return }
              offset = CGSize(width: dragStart.width + value.translation.width, height: dragStart.height + value.translation.height)
            }
            .onEnded { _ in dragStart = nil }
        )

        SettingsSheet(app: app, onDone: { visible = false })
          .frame(width: size.width, height: max(260, size.height - 34))
      }
      .frame(width: size.width, height: size.height)

      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .font(.caption2.weight(.bold))
        .frame(width: 28, height: 28)
        .background(Color.white.opacity(0.16), in: Circle())
        .contentShape(Circle())
        .gesture(resizeGesture)
        .padding(5)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14), lineWidth: 1))
    .shadow(color: .black.opacity(0.38), radius: 14, y: 8)
    .offset(offset)
    .padding(.top, 4)
    .padding(.trailing, 4)
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  private var resizeGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("MidivanaRoot"))
      .onChanged { value in
        if resizeStart == nil {
          resizeStart = size
        }
        guard let resizeStart else { return }
        size = CGSize(
          width: min(max(342, resizeStart.width + value.translation.width), 760),
          height: min(max(360, resizeStart.height + value.translation.height), 760)
        )
      }
      .onEnded { _ in
        resizeStart = nil
      }
  }
}

private struct AnimatedBackground: View {
  @ObservedObject var app: AppModel
  let hueAngle: Angle

  var body: some View {
    ZStack {
      if app.preset.theme.hueShift || app.preset.theme.colorMode == "gradient" {
        let phaseDegrees = hueAngle.degrees
        let phase = phaseDegrees * .pi / 180
        let drift = max(0, min(1, app.preset.theme.hueBackgroundDrift))
        let blend = max(0, min(1, app.preset.theme.hueBlendIntensity))
        let points = meshPoints(phase: phase, drift: drift)
        let colors = meshColors(blend: blend)
        MeshGradient(
          width: 3,
          height: 3,
          points: points,
          colors: colors
        )
        .hueRotation(.degrees(phaseDegrees * 0.16))

        LinearGradient(
          colors: [
            app.preset.theme.gradientTop.color.opacity(0.0),
            app.preset.theme.accent.color.opacity(0.18 + blend * 0.18),
            app.preset.theme.gradientBottom.color.opacity(0.0)
          ],
          startPoint: UnitPoint(x: 0.2 + cos(phase * 0.09) * 0.12, y: 0.1),
          endPoint: UnitPoint(x: 0.8 + sin(phase * 0.08) * 0.12, y: 0.95)
        )
        .blur(radius: 34 + drift * 18)
        .hueRotation(.degrees(phaseDegrees * 0.24))
        .opacity(0.35 + blend * 0.35)
        .blendMode(.plusLighter)
      } else {
        app.preset.theme.background.color
      }
    }
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  private func meshPoints(phase: Double, drift: Double) -> [SIMD2<Float>] {
    [
      SIMD2<Float>(0, 0),
      SIMD2<Float>(Float(0.5 + cos(phase * 0.21) * 0.08 * drift), 0),
      SIMD2<Float>(1, 0),
      SIMD2<Float>(0, Float(0.5 + sin(phase * 0.17) * 0.08 * drift)),
      SIMD2<Float>(
        Float(0.5 + cos(phase * 0.13) * 0.12 * drift),
        Float(0.5 + sin(phase * 0.11) * 0.12 * drift)
      ),
      SIMD2<Float>(1, Float(0.5 + cos(phase * 0.19) * 0.08 * drift)),
      SIMD2<Float>(0, 1),
      SIMD2<Float>(Float(0.5 + sin(phase * 0.15) * 0.08 * drift), 1),
      SIMD2<Float>(1, 1)
    ]
  }

  private func meshColors(blend: Double) -> [Color] {
    [
      app.preset.theme.background.color,
      app.preset.theme.gradientTop.color,
      app.preset.theme.accent.color.opacity(0.7 + blend * 0.2),
      app.preset.theme.gradientBottom.color,
      app.preset.theme.background.color.opacity(0.9),
      app.preset.theme.gradientTop.color.opacity(0.82),
      app.preset.theme.accent.color.opacity(0.55 + blend * 0.25),
      app.preset.theme.gradientBottom.color.opacity(0.9),
      app.preset.theme.background.color
    ]
  }
}

private struct TopBar: View {
  @ObservedObject var app: AppModel
  @ObservedObject private var midi: MIDIService
  @Binding var showingSettings: Bool
  @Binding var showingMacKeys: Bool
  @Binding var showingNoteRepeat: Bool

  init(app: AppModel, showingSettings: Binding<Bool>, showingMacKeys: Binding<Bool>, showingNoteRepeat: Binding<Bool>) {
    self.app = app
    self.midi = app.midi
    self._showingSettings = showingSettings
    self._showingMacKeys = showingMacKeys
    self._showingNoteRepeat = showingNoteRepeat
  }

  var body: some View {
    ZStack {
      HStack(spacing: 8) {
        if app.preset.layout != .drums && app.preset.layout != .custom {
          HTMLIconButton(label: "", theme: app.preset.theme) {
            app.preset.baseOctave = max(1, app.preset.baseOctave - 1)
          }
          .accessibilityLabel("Octave down")

          HTMLIconButton(label: "", theme: app.preset.theme) {
            app.preset.baseOctave = min(7, app.preset.baseOctave + 1)
          }
          .accessibilityLabel("Octave up")
        }
        Spacer()
      }

      if app.preset.layout == .fretboard || app.preset.layout == .keyboard {
        HStack(spacing: 12) {
          ToolbarExpressionButton(theme: app.preset.theme, active: app.preset.vibratoEnabled) { pressed in
            app.preset.vibratoEnabled = pressed
          }

          ForEach(Array(visibleQuickCCs.enumerated()), id: \.offset) { _, ccNumber in
            ToolbarCCButton(app: app, ccNumber: ccNumber)
          }
        }
      }

      HStack(spacing: 8) {
        Spacer()

        if app.preset.showMacKeyPads {
          Button {
            showingMacKeys.toggle()
          } label: {
            Image(systemName: "keyboard")
              .font(.headline.weight(.semibold))
              .frame(width: 42, height: 42)
              .background(app.preset.theme.panel.color, in: RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Mac keys")
        }

        if app.preset.showNoteRepeatControls {
          Button {
            showingNoteRepeat.toggle()
          } label: {
            Image(systemName: "repeat")
              .font(.headline.weight(.semibold))
              .frame(width: 42, height: 42)
              .background(app.preset.noteRepeatEnabled ? app.preset.theme.activePad.color : app.preset.theme.panel.color, in: RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).stroke((app.preset.noteRepeatEnabled ? app.preset.theme.activeGlow.color : app.preset.theme.padBorder.color).opacity(0.5), lineWidth: 1))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Note repeat")
        }

        Menu {
          ForEach(PerformanceLayout.allCases) { layout in
            Button {
              app.setLayout(layout)
            } label: {
              Label(layout.title, systemImage: layout.systemImage)
            }
          }
          Divider()
          Button {
            app.setCustomLayout(.editableFretboard)
          } label: {
            Label("Editable Fretboard", systemImage: "guitars")
          }
          Button {
            app.setCustomLayout(.editableDrumset)
          } label: {
            Label("Editable Drumset", systemImage: "drum")
          }
          Button {
            app.setCustomLayout(.blankGrid)
          } label: {
            Label("Blank Grid", systemImage: "square.grid.3x3")
          }
        } label: {
          Image(systemName: "rectangle.grid.2x2")
            .font(.headline.weight(.semibold))
            .frame(width: 42, height: 42)
            .background(app.preset.theme.panel.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Layout menu")

        Button {
          showingSettings = true
        } label: {
          Text("•")
            .font(.title2.weight(.bold))
            .frame(width: 46, height: 42)
            .background(app.preset.theme.panel.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
      }
    }
    .frame(height: 72)
  }

  private var visibleQuickCCs: [Int] {
    let count = max(0, app.preset.quickCCVisibleCount)
    let fallback = [app.preset.cc1Number, app.preset.cc2Number, 74, 71, 73, 11]
    return (0..<count).map { index in
      let value = app.preset.quickCCNumbers.indices.contains(index) ? app.preset.quickCCNumbers[index] : fallback[min(index, fallback.count - 1)]
      return min(max(0, value), 127)
    }
  }
}

private struct HTMLIconButton: View {
  let label: String
  let theme: ThemeSettings
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.title3.weight(.semibold))
        .frame(width: 78, height: 62)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(theme.panel.color, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.padBorder.color.opacity(0.5), lineWidth: 1))
  }
}

private struct ToolbarExpressionButton: View {
  let theme: ThemeSettings
  let active: Bool
  let action: (Bool) -> Void
  @State private var pressed = false

  var body: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .fill(active ? theme.activePad.color : theme.panel.color)
      .overlay(RoundedRectangle(cornerRadius: 12).stroke((active ? theme.activeGlow.color : theme.padBorder.color).opacity(active ? 0.7 : 0.45), lineWidth: 1))
      .shadow(color: active ? theme.activeGlow.color.opacity(0.28) : .clear, radius: 12)
      .frame(width: 160, height: 62)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            guard !pressed else { return }
            pressed = true
            action(true)
          }
          .onEnded { _ in
            pressed = false
            action(false)
          }
      )
    .accessibilityLabel("Vibrato")
  }
}

private struct ToolbarCCButton: View {
  @ObservedObject var app: AppModel
  let ccNumber: Int
  @State private var value = 64

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(app.preset.theme.panel.color)
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(app.preset.theme.padBorder.color.opacity(0.42), lineWidth: 1))

        RoundedRectangle(cornerRadius: 12)
          .fill(app.preset.theme.activeGlow.color.opacity(0.42))
          .frame(width: proxy.size.width * CGFloat(value) / 127.0)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            let ratio = max(0, min(1, drag.location.x / max(1, proxy.size.width)))
            value = Int((ratio * 127).rounded())
            app.setQuickCC(number: ccNumber, value: value)
          }
      )
    }
    .frame(width: 160, height: 62)
    .accessibilityLabel("CC \(ccNumber)")
  }
}

private struct PerformanceSurface: View {
  @ObservedObject var app: AppModel

  var body: some View {
    VStack(spacing: 2) {
      if app.preset.layout != .custom {
        FretMarkers(app: app, edge: .top)
      }

      Group {
        if app.preset.layout == .custom {
          CustomLayoutSurface(app: app)
        } else if app.preset.layout == .keyboard {
          PianoSurface(app: app)
        } else if app.preset.layout == .drums {
          DrumKitSurface(app: app)
        } else {
          PadMatrix(app: app, rows: app.currentPads)
        }
      }

      if app.preset.layout != .custom {
        FretMarkers(app: app, edge: .bottom)
      }

      if app.preset.layout == .fretboard {
        SustainBar(app: app)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct MacKeyWindow: View {
  @ObservedObject var app: AppModel
  @Binding var visible: Bool
  @Binding var offset: CGSize
  @Binding var size: CGSize
  @State private var dragStart: CGSize?
  @State private var resizeStart: CGSize?
  @State private var keyDragStart: [UUID: MacKeyPad] = [:]
  @State private var keyResizeStart: [UUID: MacKeyPad] = [:]

  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(spacing: 6) {
        HStack {
          Spacer()
          Button {
            visible = false
          } label: {
            Image(systemName: "xmark")
              .font(.caption.weight(.bold))
              .frame(width: 32, height: 28)
              .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
          }
          .buttonStyle(.plain)
          .contentShape(Rectangle())
        }
        .contentShape(Rectangle())

        GeometryReader { proxy in
          ZStack(alignment: .topLeading) {
            if app.preset.keyPadEditMode {
              ForEach($app.preset.keyPads) { $keyPad in
                keyPadView($keyPad, in: proxy.size)
              }
            } else {
              UIKitKeyPadCanvas(app: app, pads: app.preset.keyPads.map(\.normalized), theme: app.preset.theme)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
          }
          .frame(width: proxy.size.width, height: proxy.size.height)
          .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(height: max(58, size.height - 42))
        .contentShape(Rectangle())
      }
      .padding(8)
      .frame(width: size.width, height: size.height)
      .background(app.preset.theme.panel.color.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16), lineWidth: 1))

      Capsule()
        .fill(Color.white.opacity(0.42))
        .frame(width: 58, height: 7)
        .position(x: 43, y: size.height - 16)
        .contentShape(Rectangle())
        .gesture(moveGesture)

      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .font(.caption2.weight(.bold))
        .frame(width: 28, height: 28)
        .background(Color.white.opacity(0.16), in: Circle())
        .contentShape(Circle())
        .gesture(resizeGesture)
        .position(x: size.width - 16, y: size.height - 16)
    }
    .frame(width: size.width, height: size.height)
    .clipped()
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  private var moveGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("MidivanaRoot"))
      .onChanged { value in
        if dragStart == nil {
          dragStart = offset
        }
        guard let dragStart else { return }
        offset = CGSize(width: dragStart.width + value.translation.width, height: dragStart.height + value.translation.height)
      }
      .onEnded { _ in
        dragStart = nil
      }
  }

  private var resizeGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("MidivanaRoot"))
      .onChanged { value in
        if resizeStart == nil {
          resizeStart = size
        }
        guard let resizeStart else { return }
        size = CGSize(
          width: min(max(260, resizeStart.width + value.translation.width), 720),
          height: min(max(96, resizeStart.height + value.translation.height), 420)
        )
      }
      .onEnded { _ in
        resizeStart = nil
      }
  }

  @ViewBuilder
  private func keyPadView(_ keyPad: Binding<MacKeyPad>, in size: CGSize) -> some View {
    let pad = keyPad.wrappedValue.normalized
    let width = max(34, size.width * CGFloat(pad.width))
    let height = max(34, size.height * CGFloat(pad.height))
    let x = size.width * CGFloat(pad.x + pad.width / 2)
    let y = size.height * CGFloat(pad.y + pad.height / 2)

    if app.preset.keyPadEditMode {
      editableKeyPadView(keyPad, pad: pad, width: width, height: height, areaSize: size)
    } else {
      KeyPadButton(label: pad.label, width: width, height: height, theme: app.preset.theme, pressed: app.activeKeyPadIDs.contains(pad.id)) { pressed in
        if pressed {
          app.beginKeyPad(pad)
        } else {
          app.endKeyPad(pad)
        }
      }
      .position(x: x, y: y)
    }
  }

  private func keyPadTargets(in size: CGSize) -> [KeyPadHitTarget] {
    app.preset.keyPads.map { keyPad in
      let pad = keyPad.normalized
      return KeyPadHitTarget(
        id: pad.id,
        pad: pad,
        frame: CGRect(
          x: size.width * CGFloat(pad.x),
          y: size.height * CGFloat(pad.y),
          width: max(34, size.width * CGFloat(pad.width)),
          height: max(34, size.height * CGFloat(pad.height))
        )
      )
    }
  }

  private func editableKeyPadView(_ keyPad: Binding<MacKeyPad>, pad: MacKeyPad, width: CGFloat, height: CGFloat, areaSize: CGSize) -> some View {
    KeyPadFace(label: pad.label, width: width, height: height, theme: app.preset.theme, pressed: false)
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(app.preset.theme.activeGlow.color.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
      .overlay(alignment: .bottomTrailing) {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
          .font(.caption2.weight(.bold))
          .frame(width: 24, height: 24)
          .background(app.preset.theme.activeGlow.color.opacity(0.25), in: Circle())
          .contentShape(Circle())
          .highPriorityGesture(keyResizeGesture(keyPad, in: areaSize))
          .offset(x: 8, y: 8)
      }
      .contentShape(Rectangle())
      .gesture(keyMoveGesture(keyPad, in: areaSize))
      .position(
        x: areaSize.width * CGFloat(pad.x + pad.width / 2),
        y: areaSize.height * CGFloat(pad.y + pad.height / 2)
      )
  }

  private func keyMoveGesture(_ keyPad: Binding<MacKeyPad>, in areaSize: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let id = keyPad.wrappedValue.id
        if keyDragStart[id] == nil {
          keyDragStart[id] = keyPad.wrappedValue.normalized
        }
        guard let start = keyDragStart[id] else { return }
        var next = start
        next.x = start.x + Double(value.translation.width / max(1, areaSize.width))
        next.y = start.y + Double(value.translation.height / max(1, areaSize.height))
        keyPad.wrappedValue = next.normalized
      }
      .onEnded { _ in
        keyDragStart.removeValue(forKey: keyPad.wrappedValue.id)
      }
  }

  private func keyResizeGesture(_ keyPad: Binding<MacKeyPad>, in areaSize: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let id = keyPad.wrappedValue.id
        if keyResizeStart[id] == nil {
          keyResizeStart[id] = keyPad.wrappedValue.normalized
        }
        guard let start = keyResizeStart[id] else { return }
        var next = start
        next.width = start.width + Double(value.translation.width / max(1, areaSize.width))
        next.height = start.height + Double(value.translation.height / max(1, areaSize.height))
        keyPad.wrappedValue = next.normalized
      }
      .onEnded { _ in
        keyResizeStart.removeValue(forKey: keyPad.wrappedValue.id)
      }
  }
}

private struct UIKitKeyPadCanvas: UIViewRepresentable {
  @ObservedObject var app: AppModel
  let pads: [MacKeyPad]
  let theme: ThemeSettings

  func makeUIView(context: Context) -> KeyPadCanvasView {
    let view = KeyPadCanvasView()
    view.isMultipleTouchEnabled = true
    view.backgroundColor = .clear
    view.app = app
    view.pads = pads
    view.theme = theme
    return view
  }

  func updateUIView(_ uiView: KeyPadCanvasView, context: Context) {
    uiView.app = app
    uiView.pads = pads
    uiView.theme = theme
    uiView.setNeedsDisplay()
  }

  final class KeyPadCanvasView: UIView {
    weak var app: AppModel?
    var pads: [MacKeyPad] = []
    var theme = ThemeSettings()
    private var activePads: [ObjectIdentifier: MacKeyPad] = [:]

    override func draw(_ rect: CGRect) {
      super.draw(rect)
      guard let context = UIGraphicsGetCurrentContext() else { return }
      context.clear(rect)
      let activeIDs = Set(activePads.values.map(\.id)).union(app?.activeKeyPadIDs ?? [])
      for pad in pads {
        draw(pad: pad, active: activeIDs.contains(pad.id))
      }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      handle(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      handle(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window == nil {
        releaseAllTouches()
      }
    }

    private func handle(_ touches: Set<UITouch>) {
      guard let app else { return }
      var changed = false
      for touch in touches {
        let touchID = ObjectIdentifier(touch)
        let point = touch.location(in: self)
        guard let pad = pad(at: point) else {
          if let previous = activePads.removeValue(forKey: touchID) {
            app.endKeyPad(previous)
            changed = true
          }
          continue
        }
        if activePads[touchID]?.id == pad.id { continue }
        if let previous = activePads[touchID] {
          app.endKeyPad(previous)
        }
        activePads[touchID] = pad
        app.beginKeyPad(pad)
        changed = true
      }
      if changed {
        setNeedsDisplay()
      }
    }

    private func release(_ touches: Set<UITouch>) {
      guard let app else { return }
      var changed = false
      for touch in touches {
        let touchID = ObjectIdentifier(touch)
        if let previous = activePads.removeValue(forKey: touchID) {
          app.endKeyPad(previous)
          changed = true
        }
      }
      if changed {
        setNeedsDisplay()
      }
    }

    private func releaseAllTouches() {
      guard let app else {
        activePads.removeAll()
        return
      }
      let active = activePads.values
      activePads.removeAll()
      for pad in active {
        app.endKeyPad(pad)
      }
    }

    private func pad(at point: CGPoint) -> MacKeyPad? {
      pads.reversed().first { frame(for: $0).contains(point) }
    }

    private func draw(pad: MacKeyPad, active: Bool) {
      let frame = frame(for: pad)
      let path = UIBezierPath(roundedRect: frame, cornerRadius: 8)
      let fillColor = active
        ? highlightedColor(theme: theme)
        : uiColor(theme.panel, alphaMultiplier: 0.82)
      fillColor.setFill()
      path.fill()
      uiColor(active ? theme.activeGlow : theme.padBorder, alphaMultiplier: active ? 0.82 : 0.48).setStroke()
      path.lineWidth = active ? 2 : 1
      path.stroke()

      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      let fontSize = min(24, max(12, frame.height * 0.4))
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: fontSize),
        .foregroundColor: UIColor.white,
        .paragraphStyle: paragraph
      ]
      let textRect = CGRect(
        x: frame.minX + 4,
        y: frame.midY - (fontSize + 6) / 2,
        width: max(0, frame.width - 8),
        height: fontSize + 6
      )
      NSString(string: pad.label).draw(in: textRect, withAttributes: attributes)
    }

    private func frame(for pad: MacKeyPad) -> CGRect {
      let normalized = pad.normalized
      return CGRect(
        x: bounds.width * CGFloat(normalized.x),
        y: bounds.height * CGFloat(normalized.y),
        width: max(34, bounds.width * CGFloat(normalized.width)),
        height: max(34, bounds.height * CGFloat(normalized.height))
      )
    }

    private func uiColor(_ color: CodableColor, alphaMultiplier: CGFloat = 1) -> UIColor {
      UIColor(
        red: CGFloat(color.red),
        green: CGFloat(color.green),
        blue: CGFloat(color.blue),
        alpha: CGFloat(color.opacity) * alphaMultiplier
      )
    }

    private func highlightedColor(theme: ThemeSettings) -> UIColor {
      let glow = uiColor(theme.activeGlow, alphaMultiplier: 0.9)
      return glow.withAlphaComponent(max(0.72, glow.cgColor.alpha))
    }
  }
}

private struct KeyPadHitTarget: Identifiable {
  let id: UUID
  let pad: MacKeyPad
  let frame: CGRect
}

private struct NoteRepeatWindow: View {
  @ObservedObject var app: AppModel
  @Binding var visible: Bool
  @State private var offset = CGSize.zero
  @State private var dragStart: CGSize?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Capsule()
          .fill(Color.white.opacity(0.38))
          .frame(width: 34, height: 4)
        Text("Repeat")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Button {
          visible = false
        } label: {
          Image(systemName: "xmark")
            .font(.caption.weight(.bold))
            .frame(width: 26, height: 22)
        }
        .buttonStyle(.plain)
      }
      .contentShape(Rectangle())
      .gesture(moveGesture)

      Toggle("MIDI note repeat", isOn: $app.preset.noteRepeatEnabled)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Tempo")
          Spacer()
          TextField("Tempo", value: $app.preset.noteRepeatTempo, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
            .textFieldStyle(.roundedBorder)
        }
        Slider(value: tempoBinding, in: 20...300, step: 1)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Rate 1/\(app.preset.noteRepeatSubdivision)")
          .font(.caption.weight(.semibold))
        Slider(value: subdivisionBinding, in: 1...32, step: 1)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Swing \(Int(app.preset.noteRepeatSwing.rounded()))%")
          .font(.caption.weight(.semibold))
        Slider(value: $app.preset.noteRepeatSwing, in: 0...75, step: 1)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Swing subdivision \(app.preset.noteRepeatSwingSubdivision)")
          .font(.caption.weight(.semibold))
        Slider(value: swingSubdivisionBinding, in: 2...8, step: 1)
      }

      Toggle("Show repeat button", isOn: $app.preset.showNoteRepeatControls)
    }
    .padding(12)
    .frame(width: 248)
    .background(app.preset.theme.panel.color.opacity(0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16), lineWidth: 1))
    .shadow(color: .black.opacity(0.35), radius: 16, y: 9)
    .offset(offset)
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  private var moveGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("MidivanaRoot"))
      .onChanged { value in
        if dragStart == nil {
          dragStart = offset
        }
        guard let dragStart else { return }
        offset = CGSize(width: dragStart.width + value.translation.width, height: dragStart.height + value.translation.height)
      }
      .onEnded { _ in
        dragStart = nil
      }
  }

  private var tempoBinding: Binding<Double> {
    Binding {
      app.preset.noteRepeatTempo
    } set: { value in
      app.preset.noteRepeatTempo = min(max(20, value), 300)
    }
  }

  private var subdivisionBinding: Binding<Double> {
    Binding {
      Double(app.preset.noteRepeatSubdivision)
    } set: { value in
      app.preset.noteRepeatSubdivision = min(max(1, Int(value.rounded())), 32)
    }
  }

  private var swingSubdivisionBinding: Binding<Double> {
    Binding {
      Double(app.preset.noteRepeatSwingSubdivision)
    } set: { value in
      app.preset.noteRepeatSwingSubdivision = min(max(2, Int(value.rounded())), 8)
    }
  }
}

private struct KeyPadFace: View {
  let label: String
  let width: CGFloat
  let height: CGFloat
  let theme: ThemeSettings
  let pressed: Bool

  var body: some View {
    Text(label)
      .font(.headline.weight(.bold))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .frame(width: width, height: height)
      .background(pressed ? theme.activePad.color : theme.panel.color.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke((pressed ? theme.activeGlow.color : theme.padBorder.color).opacity(pressed ? 0.75 : 0.42), lineWidth: 1))
      .shadow(color: pressed ? theme.activeGlow.color.opacity(0.28) : .clear, radius: 10)
      .contentShape(Rectangle())
  }
}

private struct KeyPadButton: View {
  let label: String
  let width: CGFloat
  let height: CGFloat
  let theme: ThemeSettings
  let pressed: Bool
  let action: (Bool) -> Void
  @State private var localPressed = false

  var body: some View {
    KeyPadFace(label: label, width: width, height: height, theme: theme, pressed: pressed || localPressed)
      .highPriorityGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            guard !localPressed else { return }
            localPressed = true
            action(true)
          }
          .onEnded { _ in
            localPressed = false
            action(false)
          }
      )
      .onDisappear {
        localPressed = false
        action(false)
      }
  }
}

private struct KeyPadTouchOverlay: UIViewRepresentable {
  @ObservedObject var app: AppModel
  let targets: [KeyPadHitTarget]

  func makeUIView(context: Context) -> TouchView {
    let view = TouchView()
    view.isMultipleTouchEnabled = true
    view.backgroundColor = .clear
    view.app = app
    view.targets = targets
    return view
  }

  func updateUIView(_ uiView: TouchView, context: Context) {
    uiView.app = app
    uiView.targets = targets
  }

  final class TouchView: UIView {
    weak var app: AppModel?
    var targets: [KeyPadHitTarget] = []
    private var activeTargets: [ObjectIdentifier: KeyPadHitTarget] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      handle(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      handle(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    private func handle(_ touches: Set<UITouch>) {
      guard let app else { return }
      for touch in touches {
        let id = ObjectIdentifier(touch)
        let point = touch.location(in: self)
        guard let target = targets.reversed().first(where: { $0.frame.contains(point) }) else {
          if let previous = activeTargets.removeValue(forKey: id) {
            app.endKeyPad(previous.pad)
          }
          continue
        }
        if activeTargets[id]?.id == target.id { continue }
        if let previous = activeTargets[id] {
          app.endKeyPad(previous.pad)
        }
        activeTargets[id] = target
        app.beginKeyPad(target.pad)
      }
    }

    private func release(_ touches: Set<UITouch>) {
      guard let app else { return }
      for touch in touches {
        let id = ObjectIdentifier(touch)
        if let previous = activeTargets.removeValue(forKey: id) {
          app.endKeyPad(previous.pad)
        }
      }
    }
  }
}

private struct PositionedPad: Identifiable {
  let id: String
  let pad: NotePad
  let frame: CGRect
  let shape: PadShape
}

private struct PadHitTarget: Identifiable {
  let id: String
  let pad: NotePad
  let frame: CGRect
}

private struct MultiTouchPadOverlay: UIViewRepresentable {
  @ObservedObject var app: AppModel
  let targets: [PadHitTarget]

  func makeUIView(context: Context) -> TouchView {
    let view = TouchView()
    view.isMultipleTouchEnabled = true
    view.backgroundColor = .clear
    view.app = app
    view.targets = targets
    return view
  }

  func updateUIView(_ uiView: TouchView, context: Context) {
    uiView.app = app
    uiView.targets = targets
  }

  final class TouchView: UIView {
    weak var app: AppModel?
    var targets: [PadHitTarget] = []
    private var activePads: [ObjectIdentifier: NotePad] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      handle(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      handle(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      release(touches)
    }

    private func handle(_ touches: Set<UITouch>) {
      guard let app else { return }
      for touch in touches {
        let key = ObjectIdentifier(touch)
        guard let pad = pad(for: touch) else { continue }
        if activePads[key]?.id == pad.id { continue }
        if let previous = activePads[key] {
          app.release(previous)
          app.resetBend(channel: previous.channel)
        }
        activePads[key] = pad
        app.press(pad, touchIntensity: touchIntensity(for: touch))
      }
    }

    private func release(_ touches: Set<UITouch>) {
      guard let app else { return }
      for touch in touches {
        let key = ObjectIdentifier(touch)
        guard let pad = activePads.removeValue(forKey: key) else { continue }
        app.release(pad)
        app.resetBend(channel: pad.channel)
      }
    }

    private func pad(for touch: UITouch) -> NotePad? {
      guard bounds.width > 0, bounds.height > 0 else { return nil }
      let location = touch.location(in: self)
      let normalized = CGPoint(x: location.x / bounds.width, y: location.y / bounds.height)
      return targets.reversed().first { $0.frame.contains(normalized) }?.pad
    }

    private func touchIntensity(for touch: UITouch) -> Double {
      if touch.maximumPossibleForce > 0 && touch.force > 0 {
        return Double(touch.force / touch.maximumPossibleForce)
      }
      let radius = Double(touch.majorRadius)
      return max(0, min(1, (radius - 10) / 34))
    }
  }
}

private struct PositionedPadSurface: View {
  @ObservedObject var app: AppModel
  let pads: [PositionedPad]

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        ForEach(pads) { positioned in
          let pad = positioned.pad
          let active = app.isActive(note: pad.note, channel: pad.channel)
          PadChrome(
            title: app.preset.theme.showNoteNames ? pad.title : "",
            subtitle: app.preset.theme.showNoteNames ? pad.subtitle : "",
            shape: positioned.shape,
            active: active,
            fill: padFill(for: pad, active: active),
            border: padBorder(for: pad, active: active),
            glowColor: padGlow(for: pad, active: active),
            glow: app.preset.theme.glowOnTouch,
            imageData: nil,
            labelSize: 64,
            rotation: 0
          )
          .frame(width: proxy.size.width * positioned.frame.width, height: proxy.size.height * positioned.frame.height)
          .position(
            x: proxy.size.width * positioned.frame.midX,
            y: proxy.size.height * positioned.frame.midY
          )
          .allowsHitTesting(false)
        }
      }
      MultiTouchPadOverlay(app: app, targets: pads.map { PadHitTarget(id: $0.id, pad: $0.pad, frame: $0.frame) })
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }

  private func padFill(for pad: NotePad, active: Bool) -> Color {
    if active && (app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift) {
      return themedActiveFillColor(app.preset.theme, row: pad.row, maxRow: 7)
    }
    if active { return app.preset.theme.activePad.color }
    if app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift {
      return themedGradientColor(app.preset.theme, row: pad.row, maxRow: 7)
    }
    return app.preset.theme.padFillMode == "outline" ? .clear : app.preset.theme.pad.color
  }

  private func padBorder(for pad: NotePad, active: Bool) -> Color {
    if active && (app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift) {
      return themedActiveGlowColor(app.preset.theme, row: pad.row, maxRow: 7)
    }
    if active { return app.preset.theme.activeGlow.color }
    if app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift {
      return themedBorderColor(app.preset.theme, row: pad.row, maxRow: 7)
    }
    return app.preset.theme.padBorder.color
  }

  private func padGlow(for pad: NotePad, active: Bool) -> Color {
    if app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift {
      return active ? themedActiveGlowColor(app.preset.theme, row: pad.row, maxRow: 7) : themedGlowColor(app.preset.theme, row: pad.row, maxRow: 7)
    }
    return active ? app.preset.theme.activeGlow.color : app.preset.theme.padGlow.color
  }
}

private struct PianoSurface: View {
  @ObservedObject var app: AppModel

  var body: some View {
    PositionedPadSurface(app: app, pads: pads)
  }

  private var pads: [PositionedPad] {
    let octaves = max(1, min(4, app.preset.keyboardOctaves))
    let stacks = max(1, min(4, app.preset.keyboardRows))
    let whiteCols = octaves * 7
    let totalRows = stacks * 2 + max(0, stacks - 1)
    let unitW = 1.0 / Double(whiteCols)
    let unitH = 1.0 / Double(totalRows)
    let base = 12 * (app.preset.baseOctave + 1) + app.preset.rootNote
    let whiteSemitones = [0, 2, 4, 5, 7, 9, 11]
    let blackSemitones = [(0, 1), (1, 3), (3, 6), (4, 8), (5, 10)]
    var result: [PositionedPad] = []

    for stack in 0..<stacks {
      let stackOffset = stack * 3
      let blackRow = stackOffset
      let whiteRow = stackOffset + 1
      let stackBase = base + stack * octaves * 12

      for octave in 0..<octaves {
        for white in 0..<7 {
          let note = stackBase + octave * 12 + whiteSemitones[white]
          let col = octave * 7 + white
          let pad = NotePad(
            id: "piano-w-\(stack)-\(octave)-\(white)",
            note: note,
            title: MusicTheory.pitchName(note),
            subtitle: MusicTheory.noteName(note),
            row: whiteRow,
            column: col,
            channel: app.preset.midiChannel,
            isInScale: true
          )
          result.append(PositionedPad(
            id: pad.id,
            pad: pad,
            frame: CGRect(x: Double(col) * unitW, y: Double(whiteRow) * unitH, width: unitW * 0.92, height: unitH * 0.94),
            shape: app.preset.theme.shape
          ))
        }

        for black in blackSemitones {
          let note = stackBase + octave * 12 + black.1
          let col = octave * 7 + black.0
          let pad = NotePad(
            id: "piano-b-\(stack)-\(octave)-\(black.1)",
            note: note,
            title: MusicTheory.pitchName(note),
            subtitle: MusicTheory.noteName(note),
            row: blackRow,
            column: col,
            channel: app.preset.midiChannel,
            isInScale: true
          )
          result.append(PositionedPad(
            id: pad.id,
            pad: pad,
            frame: CGRect(x: (Double(col) + 0.45) * unitW, y: Double(blackRow) * unitH, width: unitW * 0.82, height: unitH * 0.84),
            shape: app.preset.theme.shape
          ))
        }
      }
    }

    return result
  }
}

private func themedGradientColor(_ theme: ThemeSettings, row: Int, maxRow: Double) -> Color {
  let t = gradientRatio(row: row, maxRow: maxRow)
  return blendedColor(theme.gradientTop, theme.gradientBottom, t: t)
}

private func themedActiveFillColor(_ theme: ThemeSettings, row: Int, maxRow: Double) -> Color {
  let t = gradientRatio(row: row, maxRow: maxRow)
  let base = blendedCodableColor(theme.gradientTop, theme.gradientBottom, t: t)
  let active = blendedCodableColor(theme.activePad, theme.accent, t: 0.35)
  return blendedColor(base, active, t: 0.58, opacity: max(0.92, theme.activePad.opacity))
}

private func themedBorderColor(_ theme: ThemeSettings, row: Int, maxRow: Double) -> Color {
  let t = gradientRatio(row: row, maxRow: maxRow)
  let inverse = blendedCodableColor(theme.gradientBottom, theme.gradientTop, t: t)
  let tinted = blendedCodableColor(inverse, theme.padBorder, t: 0.56)
  return blendedColor(tinted, theme.accent, t: 0.18, opacity: max(0.82, theme.padBorder.opacity))
}

private func themedGlowColor(_ theme: ThemeSettings, row: Int, maxRow: Double) -> Color {
  let t = gradientRatio(row: row, maxRow: maxRow)
  let base = blendedCodableColor(theme.gradientTop, theme.gradientBottom, t: 1 - t)
  return blendedColor(base, theme.padGlow, t: 0.45, opacity: max(0.32, theme.padGlow.opacity))
}

private func themedActiveGlowColor(_ theme: ThemeSettings, row: Int, maxRow: Double) -> Color {
  let t = gradientRatio(row: row, maxRow: maxRow)
  let base = blendedCodableColor(theme.gradientBottom, theme.gradientTop, t: t)
  let hot = blendedCodableColor(theme.activeGlow, theme.accent, t: 0.4)
  return blendedColor(base, hot, t: 0.64, opacity: max(0.76, theme.activeGlow.opacity))
}

private func gradientRatio(row: Int, maxRow: Double) -> Double {
  max(0, min(1, Double(row) / max(1, maxRow)))
}

private func blendedCodableColor(_ start: CodableColor, _ end: CodableColor, t: Double) -> CodableColor {
  let amount = max(0, min(1, t))
  return CodableColor(
    red: start.red + (end.red - start.red) * amount,
    green: start.green + (end.green - start.green) * amount,
    blue: start.blue + (end.blue - start.blue) * amount,
    opacity: start.opacity + (end.opacity - start.opacity) * amount
  )
}

private func blendedColor(_ start: CodableColor, _ end: CodableColor, t: Double, opacity: Double? = nil) -> Color {
  let color = blendedCodableColor(start, end, t: t)
  return Color(
    red: color.red,
    green: color.green,
    blue: color.blue,
    opacity: opacity ?? color.opacity
  )
}

private struct DrumKitSurface: View {
  @ObservedObject var app: AppModel

  var body: some View {
    PositionedPadSurface(app: app, pads: pads)
  }

  private var pads: [PositionedPad] {
    drumLayout().compactMap { entry in
      let pad = NotePad(
        id: entry.id,
        note: entry.note,
        title: entry.title,
        subtitle: MusicTheory.noteName(entry.note),
        row: entry.row,
        column: entry.col,
        channel: 10,
        isInScale: true
      )
      return PositionedPad(
        id: pad.id,
        pad: pad,
        frame: frame(for: entry),
        shape: shape(for: entry)
      )
    }
  }

  private struct DrumEntry {
    let id: String
    let title: String
    let note: Int
    let row: Int
    let col: Int
    let colSpan: Int
    let rowSpan: Int
    let shape: PadShape
  }

  private func frame(for entry: DrumEntry) -> CGRect {
    let cols = 12.0
    let rows = Double(drumGridRows())
    let gap = 0.012
    let rawX = (Double(entry.col - 1) / cols) + gap / 2
    let y = (Double(entry.row - 1) / rows) + gap / 2
    let width = Double(entry.colSpan) / cols - gap
    let height = Double(entry.rowSpan) / rows - gap
    let x = app.preset.drumFlip ? 1 - rawX - width : rawX
    return expandedFrame(
      CGRect(x: x, y: y, width: max(0.04, width), height: max(0.04, height)),
      for: entry.id
    )
  }

  private func expandedFrame(_ frame: CGRect, for id: String) -> CGRect {
    let isMainDrum = id.hasPrefix("tom") || id == "snare" || id == "rim" || id == "kick"
    let scaleX = id == "kick" ? 1.04 : (isMainDrum ? 1.0 : 1.0)
    let scaleY = id == "kick" ? 1.04 : (isMainDrum ? 1.0 : 1.0)
    let nextWidth = min(0.98, frame.width * scaleX)
    let nextHeight = min(0.98, frame.height * scaleY)
    let nextX = min(max(0, frame.midX - nextWidth / 2), 1 - nextWidth)
    let nextY = min(max(0, frame.midY - nextHeight / 2), 1 - nextHeight)
    return CGRect(x: nextX, y: nextY, width: nextWidth, height: nextHeight)
  }

  private func shape(for entry: DrumEntry) -> PadShape {
    if entry.id.hasPrefix("cymbal") || entry.id.hasPrefix("hihat") {
      return app.preset.theme.shape == .circle ? .capsule : app.preset.theme.shape
    }
    return app.preset.theme.shape
  }

  private func drumLayout() -> [DrumEntry] {
    let cols = 12
    let cymbals = max(1, min(12, app.preset.drumCymbalCount))
    let toms = max(1, min(12, app.preset.drumTomCount))
    let cymbalRows = max(1, min(3, app.preset.drumCymbalRows))
    let tomRows = max(1, min(3, app.preset.drumTomRows))
    let cymbalNotes = [49, 51, 57, 55, 52, 59]
    let tomNotes = [50, 47, 45, 43, 41]
    var entries: [DrumEntry] = []
    var cymbalIndex = 0
    let cymbalsPerRow = Int(ceil(Double(cymbals) / Double(cymbalRows)))
    for rowIndex in 0..<cymbalRows {
      let remaining = cymbals - cymbalIndex
      let count = min(cymbalsPerRow, remaining)
      if count <= 0 { break }
      let span = max(2, cols / count)
      for item in 0..<count {
        let col = 1 + item * span
        let colSpan = item == count - 1 ? cols - (col - 1) : span
        entries.append(DrumEntry(
          id: "cymbal-\(cymbalIndex + 1)",
          title: "Cymbal \(cymbalIndex + 1)",
          note: cymbalNotes[cymbalIndex % cymbalNotes.count],
          row: 1 + rowIndex,
          col: col,
          colSpan: colSpan,
          rowSpan: 1,
          shape: .capsule
        ))
        cymbalIndex += 1
      }
    }

    let openHatRow = 1 + cymbalRows
    entries.append(DrumEntry(id: "hihat-open", title: "Open hi-hat", note: 46, row: openHatRow, col: 1, colSpan: 3, rowSpan: 1, shape: .capsule))
    let closedHatRow = openHatRow + 1
    entries.append(DrumEntry(id: "hihat", title: "Hi-hat", note: 42, row: closedHatRow, col: 1, colSpan: 3, rowSpan: 1, shape: .capsule))

    let tomsPerRow = Int(ceil(Double(toms) / Double(tomRows)))
    var tomIndex = 0
    for rowIndex in 0..<tomRows {
      let remaining = toms - tomIndex
      let count = min(tomsPerRow, remaining)
      if count <= 0 { break }
      let row = closedHatRow + rowIndex
      let start = rowIndex == 0 ? 4 : 3
      let width = rowIndex == 0 ? cols - (start - 1) : min(10, cols - (start - 1))
      let span = max(2, width / count)
      for item in 0..<count {
        let col = start + item * span
        let colSpan = item == count - 1 ? min(span, cols - (col - 1)) : span
        entries.append(DrumEntry(
          id: "tom-\(tomIndex + 1)",
          title: "Tom \(tomIndex + 1)",
          note: tomNotes[tomIndex % tomNotes.count],
          row: row,
          col: col,
          colSpan: colSpan,
          rowSpan: 1,
          shape: .circle
        ))
        tomIndex += 1
      }
    }

    let rimRow = closedHatRow + tomRows
    entries.append(DrumEntry(id: "rim", title: "Rim", note: 37, row: rimRow, col: 1, colSpan: 2, rowSpan: 1, shape: .rounded))
    entries.append(DrumEntry(id: "snare", title: "Snare", note: 38, row: rimRow, col: 3, colSpan: 5, rowSpan: 1, shape: .circle))
    let kickRow = rimRow + 1
    entries.append(DrumEntry(id: "kick", title: "Kick", note: 36, row: kickRow, col: 3, colSpan: 8, rowSpan: 2, shape: .circle))
    return entries
  }

  private func drumGridRows() -> Int {
    let cymbalRows = max(1, min(3, app.preset.drumCymbalRows))
    let tomRows = max(1, min(3, app.preset.drumTomRows))
    let closedHatRow = cymbalRows + 2
    let rimRow = closedHatRow + tomRows
    let kickRow = rimRow + 1
    return max(6, kickRow + 1)
  }
}

private enum FretMarkerEdge {
  case top
  case bottom
}

private struct FretMarkers: View {
  @ObservedObject var app: AppModel
  let edge: FretMarkerEdge
  private let markerFrets: Set<Int> = [3, 5, 7, 9, 12]

  var body: some View {
    let rawOffset = CGFloat(app.preset.theme.markerOffset)
    let directedOffset = edge == .top ? -rawOffset : rawOffset
    HStack(spacing: CGFloat(app.preset.theme.padGap)) {
      ForEach(0..<app.preset.fretCount, id: \.self) { fret in
        marker(for: fret)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(height: app.preset.theme.markerMode == "off" ? 0 : 6)
    .padding(.vertical, max(0, rawOffset / 28))
    .offset(y: directedOffset)
    .opacity(app.preset.layout == .fretboard && app.preset.theme.markerMode != "pads" && app.preset.theme.markerMode != "off" ? 1 : 0)
  }

  @ViewBuilder
  private func marker(for fret: Int) -> some View {
    let isMarker = markerFrets.contains(fret)
    let color = app.preset.theme.markerColor.color
    switch app.preset.theme.markerShape {
    case "bar":
      RoundedRectangle(cornerRadius: 4)
        .fill(isMarker ? color : .clear)
        .frame(width: 16, height: 4)
        .shadow(color: isMarker ? color : .clear, radius: 8)
    case "square":
      RoundedRectangle(cornerRadius: 2)
        .fill(isMarker ? color : .clear)
        .frame(width: 6, height: 6)
        .shadow(color: isMarker ? color : .clear, radius: 8)
    case "diamond":
      RoundedRectangle(cornerRadius: 2)
        .fill(isMarker ? color : .clear)
        .frame(width: 8, height: 8)
        .rotationEffect(.degrees(45))
        .shadow(color: isMarker ? color : .clear, radius: 8)
    default:
      Circle()
        .fill(isMarker ? color : .clear)
        .frame(width: 6, height: 6)
        .shadow(color: isMarker ? color : .clear, radius: 8)
    }
  }
}

private struct SustainBar: View {
  @ObservedObject var app: AppModel
  @State private var isPressed = false

  var body: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(app.sustainButtonActive ? app.preset.theme.activePad.color : app.preset.theme.panel.color)
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(app.sustainButtonActive ? 0.6 : 0.1), lineWidth: 1))
      .shadow(color: app.sustainButtonActive ? app.preset.theme.activeGlow.color.opacity(0.35) : .clear, radius: 12)
      .frame(height: 118)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            guard !isPressed else { return }
            isPressed = true
            app.beginSustainControl()
          }
          .onEnded { _ in
            isPressed = false
            app.endSustainControl()
          }
      )
    .accessibilityLabel("Sustain")
  }
}

private struct PadMatrix: View {
  @ObservedObject var app: AppModel
  let rows: [[NotePad]]

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        ForEach(hitTargets(in: proxy.size)) { target in
          PlayablePad(app: app, pad: target.pad)
            .frame(width: proxy.size.width * target.frame.width, height: proxy.size.height * target.frame.height)
            .position(
              x: proxy.size.width * target.frame.midX,
              y: proxy.size.height * target.frame.midY
            )
            .allowsHitTesting(false)
        }

        if app.preset.theme.markerMode == "pads" || app.preset.theme.markerMode == "both" {
          ForEach(hitTargets(in: proxy.size).filter { [3, 5, 7, 9, 12].contains($0.pad.column) }) { target in
            Circle()
              .fill(app.preset.theme.markerColor.color)
              .frame(width: 6, height: 6)
              .position(
                x: proxy.size.width * target.frame.midX,
                y: proxy.size.height * target.frame.midY
              )
          }
        }

        MultiTouchPadOverlay(app: app, targets: hitTargets(in: proxy.size))
          .frame(width: proxy.size.width, height: proxy.size.height)
      }
    }
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  private var rowSpacing: CGFloat {
    CGFloat(app.preset.layout == .fretboard ? app.preset.theme.rowGap : 12)
  }

  private var columnSpacing: CGFloat {
    CGFloat(app.preset.layout == .fretboard ? app.preset.theme.padGap : 12)
  }

  private func hitTargets(in size: CGSize) -> [PadHitTarget] {
    guard !rows.isEmpty, size.width > 0, size.height > 0 else { return [] }
    let rowCount = rows.count
    let maxRowSide = (size.height - rowSpacing * CGFloat(max(0, rowCount - 1))) / CGFloat(rowCount)
    guard maxRowSide > 0 else { return [] }
    let widestRow = rows.map(\.count).max() ?? 1
    let widestColSide = (size.width - columnSpacing * CGFloat(max(0, widestRow - 1))) / CGFloat(widestRow)
    let side = min(maxRowSide, widestColSide)
    let totalHeight = side * CGFloat(rowCount) + rowSpacing * CGFloat(max(0, rowCount - 1))
    let yOrigin = max(0, (size.height - totalHeight) / 2)
    var targets: [PadHitTarget] = []
    for rowIndex in rows.indices {
      let row = rows[rowIndex]
      let colCount = row.count
      guard colCount > 0 else { continue }
      let colWidth = (size.width - columnSpacing * CGFloat(max(0, colCount - 1))) / CGFloat(colCount)
      guard colWidth > 0 else { continue }
      let rowSide = min(side, colWidth)
      for colIndex in row.indices {
        let x = CGFloat(colIndex) * (colWidth + columnSpacing) + (colWidth - rowSide) / 2
        let y = yOrigin + CGFloat(rowIndex) * (rowSide + rowSpacing)
        let frame = CGRect(
          x: x / size.width,
          y: y / size.height,
          width: rowSide / size.width,
          height: rowSide / size.height
        )
        targets.append(PadHitTarget(id: row[colIndex].id, pad: row[colIndex], frame: frame))
      }
    }
    return targets
  }
}

private struct PlayablePad: View {
  @ObservedObject var app: AppModel
  let pad: NotePad

  var body: some View {
    let active = app.isActive(note: pad.note, channel: pad.channel)
      PadChrome(
        title: app.preset.theme.showNoteNames ? pad.title : "",
        subtitle: app.preset.theme.showNoteNames ? pad.subtitle : "",
        shape: app.preset.theme.shape,
        active: active,
        fill: fillColor(active: active),
        border: borderColor(active: active),
        glowColor: glowColor(active: active),
        glow: app.preset.theme.glowOnTouch,
        imageData: nil,
        labelSize: 64,
        rotation: 0
      )
    .aspectRatio(aspectRatio, contentMode: .fit)
    .scaleEffect(active && app.preset.theme.scaleOnTouch ? 1.06 : 1)
    .animation(.easeOut(duration: 0.08), value: active)
    .allowsHitTesting(false)
  }

  private var aspectRatio: CGFloat {
    switch app.preset.layout {
    case .fretboard: return 1
    case .keyboard: return 1
    case .drums: return 1.16
    case .custom: return 1
    }
  }

  private func fillColor(active: Bool) -> Color {
    if active && (app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift) {
      return themedActiveFillColor(app.preset.theme, row: pad.row, maxRow: 5)
    }
    if active { return app.preset.theme.activePad.color }
    if app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift {
      return themedGradientColor(app.preset.theme, row: pad.row, maxRow: 5)
    }
    return app.preset.theme.padFillMode == "outline" ? .clear : app.preset.theme.pad.color
  }

  private func borderColor(active: Bool) -> Color {
    if active && (app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift) {
      return themedActiveGlowColor(app.preset.theme, row: pad.row, maxRow: 5)
    }
    if active { return app.preset.theme.activeGlow.color }
    if app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift {
      return themedBorderColor(app.preset.theme, row: pad.row, maxRow: 5)
    }
    return app.preset.theme.padBorder.color
  }

  private func glowColor(active: Bool) -> Color {
    if app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift {
      return active ? themedActiveGlowColor(app.preset.theme, row: pad.row, maxRow: 5) : themedGlowColor(app.preset.theme, row: pad.row, maxRow: 5)
    }
    return active ? app.preset.theme.activeGlow.color : app.preset.theme.padGlow.color
  }
}

private struct PadChrome: View {
  @Environment(\.midivanaHueAngle) private var hueAngle
  @Environment(\.midivanaPadHueAmount) private var padHueAmount
  @Environment(\.midivanaPadBorderWidth) private var padBorderWidth
  let title: String
  let subtitle: String
  let shape: PadShape
  let active: Bool
  let fill: Color
  let border: Color
  let glowColor: Color
  let glow: Bool
  let imageData: Data?
  let labelSize: Double
  let rotation: Double

  var body: some View {
    ZStack {
      PadShapePath(shape: shape)
        .fill(fill)
        .hueRotation(padHueAngle)
        .overlay(
          PadShapePath(shape: shape)
            .stroke(border, lineWidth: active ? max(2.5, padBorderWidth + 0.75) : padBorderWidth)
            .hueRotation(padBorderHueAngle)
        )
        .shadow(color: glow ? glowColor.opacity(active ? 0.82 : 0.34) : .clear, radius: active ? 22 : 16)

      if let imageData, let uiImage = UIImage(data: imageData) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
          .compositingGroup()
          .hueRotation(.zero)
          .clipShape(PadShapePath(shape: shape))
      }

      VStack(spacing: 3) {
        if !title.isEmpty {
          Text(title)
            .font(.system(size: labelSize, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.64))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
        }
      }
      .padding(5)
      .rotationEffect(.degrees(rotation))
    }
  }

  private var padHueAngle: Angle {
    .degrees(hueAngle.degrees * max(0, padHueAmount) / 360.0)
  }

  private var padBorderHueAngle: Angle {
    .degrees(hueAngle.degrees * max(0, padHueAmount + 72) / 360.0)
  }
}

private struct PadShapePath: Shape {
  let shape: PadShape

  func path(in rect: CGRect) -> Path {
    switch shape {
    case .rounded:
      return RoundedRectangle(cornerRadius: 16, style: .continuous).path(in: rect)
    case .square:
      return RoundedRectangle(cornerRadius: 0, style: .continuous).path(in: rect)
    case .circle:
      return Circle().path(in: rect)
    case .capsule:
      return Capsule().path(in: rect)
    case .hex:
      return polygon(in: rect, points: [(0.2, 0), (0.8, 0), (1, 0.5), (0.8, 1), (0.2, 1), (0, 0.5)])
    case .diamond:
      return polygon(in: rect, points: [(0.5, 0.02), (0.98, 0.5), (0.5, 0.98), (0.02, 0.5)])
    case .octagon:
      return polygon(in: rect, points: [(0.24, 0), (0.76, 0), (1, 0.24), (1, 0.76), (0.76, 1), (0.24, 1), (0, 0.76), (0, 0.24)])
    case .triangle:
      return polygon(in: rect, points: [(0.5, 0.04), (0.96, 0.96), (0.04, 0.96)])
    case .star:
      return polygon(in: rect, points: [(0.5, 0.02), (0.61, 0.35), (0.96, 0.35), (0.68, 0.56), (0.79, 0.96), (0.5, 0.72), (0.21, 0.96), (0.32, 0.56), (0.04, 0.35), (0.39, 0.35)])
    case .pentagon:
      return polygon(in: rect, points: [(0.5, 0.02), (0.98, 0.38), (0.8, 0.98), (0.2, 0.98), (0.02, 0.38)])
    case .spark:
      return polygon(in: rect, points: [(0.5, 0), (0.62, 0.33), (1, 0.5), (0.62, 0.67), (0.5, 1), (0.38, 0.67), (0, 0.5), (0.38, 0.33)])
    }
  }

  private func polygon(in rect: CGRect, points: [(CGFloat, CGFloat)]) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: CGPoint(x: rect.minX + rect.width * first.0, y: rect.minY + rect.height * first.1))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: rect.minX + rect.width * point.0, y: rect.minY + rect.height * point.1))
    }
    path.closeSubpath()
    return path
  }
}

private struct CustomLayoutSurface: View {
  @ObservedObject var app: AppModel
  @State private var selectedItemID: UUID?
  @State private var editorVisible = false
  @State private var editMode = false
  @State private var editorOffset = CGSize.zero
  @State private var undoStack: [[CustomItem]] = []
  @State private var redoStack: [[CustomItem]] = []
  @State private var copiedItem: CustomItem?

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        if editMode && app.preset.customLayout.snapToGrid {
          CustomSnapGridOverlay(
            columns: app.preset.customLayout.gridColumns,
            rows: app.preset.customLayout.gridRows,
            snapGrid: app.preset.customLayout.snapGrid,
            flipped: app.preset.customLayout.flipHorizontal
          )
          .allowsHitTesting(false)
          .zIndex(4)
        }

        ForEach($app.preset.customLayout.items) { $item in
          let isSelected = selectedItemID == item.id
          let itemWidth = max(44, proxy.size.width * item.width)
          let itemHeight = max(36, proxy.size.height * item.height)
          let displayX = app.preset.customLayout.flipHorizontal ? 1 - item.x - item.width : item.x
          let itemPosition = CGPoint(
            x: proxy.size.width * (displayX + item.width / 2),
            y: proxy.size.height * (item.y + item.height / 2)
          )

          CustomItemControl(app: app, item: $item, showLabels: app.preset.customLayout.showLabels)
            .frame(
              width: itemWidth,
              height: itemHeight
            )
            .position(itemPosition)
            .allowsHitTesting(!editMode && !isTouchSurfacePlayable(item.kind))
            .simultaneousGesture(
              TapGesture().onEnded {
                selectedItemID = item.id
              }
            )

          if editMode {
            CustomEditableItemOverlay(
              item: $item,
              selected: isSelected,
              areaSize: proxy.size,
              snapToGrid: app.preset.customLayout.snapToGrid,
              gridColumns: app.preset.customLayout.gridColumns,
              gridRows: app.preset.customLayout.gridRows,
              snapGrid: app.preset.customLayout.snapGrid,
              flipped: app.preset.customLayout.flipHorizontal,
              shape: item.shape
            ) {
              selectedItemID = item.id
            } onBeginEdit: {
              recordUndo()
            }
            .frame(width: itemWidth, height: itemHeight)
            .position(itemPosition)
            .zIndex(20)
          }
        }

        if !editMode {
          CustomMultiTouchOverlay(app: app, targets: customTouchTargets())
            .frame(width: proxy.size.width, height: proxy.size.height)
            .zIndex(30)
        }

        if editorVisible {
          CustomEditorPanel(
            app: app,
            selectedItemID: $selectedItemID,
            visible: $editorVisible,
            editMode: $editMode,
            offset: $editorOffset,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            copiedItem: $copiedItem,
            onUndo: undoLayout,
            onRedo: redoLayout,
            onBeginEdit: recordUndo
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(.top, 4)
          .padding(.trailing, 4)
          .zIndex(50)
        } else {
          Button {
            editorVisible = true
          } label: {
            HStack(spacing: 2) {
              Text("+")
                .font(.title3.weight(.bold))
              Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
            }
            .frame(width: 52, height: 46)
            .background(app.preset.theme.panel.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14), lineWidth: 1))
          }
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(.top, 4)
          .padding(.trailing, 4)
          .zIndex(50)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .coordinateSpace(name: "CustomLayoutCanvas")
    }
  }

  private func recordUndo() {
    undoStack.append(app.preset.customLayout.items)
    if undoStack.count > 60 {
      undoStack.removeFirst()
    }
    redoStack.removeAll()
  }

  private func undoLayout() {
    guard let previous = undoStack.popLast() else { return }
    redoStack.append(app.preset.customLayout.items)
    app.releaseAll()
    app.preset.customLayout.items = previous
    selectedItemID = previous.first?.id
  }

  private func redoLayout() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(app.preset.customLayout.items)
    app.releaseAll()
    app.preset.customLayout.items = next
    selectedItemID = next.first?.id
  }

  private func customTouchTargets() -> [CustomTouchTarget] {
    app.preset.customLayout.items.compactMap { item in
      guard isTouchSurfacePlayable(item.kind) else { return nil }
      let displayX = app.preset.customLayout.flipHorizontal ? 1 - item.x - item.width : item.x
      return CustomTouchTarget(
        id: item.id,
        item: item,
        frame: CGRect(x: displayX, y: item.y, width: item.width, height: item.height),
        shape: item.shape
      )
    }
  }

  private func isTouchSurfacePlayable(_ kind: CustomItemKind) -> Bool {
    switch kind {
    case .note, .sustain, .panic, .keyCommand:
      return true
    case .ccSliderX, .ccSliderY, .label, .image, .video:
      return false
    }
  }
}

private struct CustomTouchTarget: Identifiable {
  let id: UUID
  let item: CustomItem
  let frame: CGRect
  let shape: PadShape
}

private struct CustomMultiTouchOverlay: UIViewRepresentable {
  @ObservedObject var app: AppModel
  let targets: [CustomTouchTarget]

  func makeUIView(context: Context) -> CustomTouchView {
    let view = CustomTouchView()
    view.isMultipleTouchEnabled = true
    view.backgroundColor = .clear
    view.app = app
    view.targets = targets
    return view
  }

  func updateUIView(_ uiView: CustomTouchView, context: Context) {
    uiView.app = app
    uiView.targets = targets
  }

  final class CustomTouchView: UIView {
    var app: AppModel?
    var targets: [CustomTouchTarget] = []
    private var activeTargets: [ObjectIdentifier: UUID] = [:]

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      target(at: point) != nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      for touch in touches {
        enterTarget(at: touch.location(in: self), touch: touch)
      }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      for touch in touches {
        let key = ObjectIdentifier(touch)
        let next = target(at: touch.location(in: self))
        if activeTargets[key] == next?.id { continue }
        if let previousID = activeTargets[key] {
          releaseTarget(id: previousID)
        }
        if let next {
          activeTargets[key] = next.id
          app?.press(item: next.item)
        } else {
          activeTargets.removeValue(forKey: key)
        }
      }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      end(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      end(touches)
    }

    private func enterTarget(at point: CGPoint, touch: UITouch) {
      guard let target = target(at: point) else { return }
      activeTargets[ObjectIdentifier(touch)] = target.id
      app?.press(item: target.item)
    }

    private func end(_ touches: Set<UITouch>) {
      for touch in touches {
        let key = ObjectIdentifier(touch)
        if let id = activeTargets.removeValue(forKey: key) {
          releaseTarget(id: id)
        }
      }
    }

    private func releaseTarget(id: UUID) {
      guard let target = targets.first(where: { $0.id == id }) else { return }
      app?.release(item: target.item)
    }

    private func target(at point: CGPoint) -> CustomTouchTarget? {
      guard bounds.width > 0, bounds.height > 0 else { return nil }
      let normalized = CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
      return targets.reversed().first { target in
        guard target.frame.contains(normalized) else { return false }
        let local = CGPoint(
          x: (normalized.x - target.frame.minX) / max(0.0001, target.frame.width),
          y: (normalized.y - target.frame.minY) / max(0.0001, target.frame.height)
        )
        return contains(local: local, in: target)
      }
    }

    private func contains(local point: CGPoint, in target: CustomTouchTarget) -> Bool {
      switch target.shape {
      case .rounded, .square:
        return true
      case .circle:
        let dx = (point.x - 0.5) / 0.5
        let dy = (point.y - 0.5) / 0.5
        return dx * dx + dy * dy <= 1
      case .capsule:
        return capsuleContains(local: point, frame: target.frame)
      case .hex:
        return polygonContains(point, points: [(0.2, 0), (0.8, 0), (1, 0.5), (0.8, 1), (0.2, 1), (0, 0.5)])
      case .diamond:
        return polygonContains(point, points: [(0.5, 0.02), (0.98, 0.5), (0.5, 0.98), (0.02, 0.5)])
      case .octagon:
        return polygonContains(point, points: [(0.24, 0), (0.76, 0), (1, 0.24), (1, 0.76), (0.76, 1), (0.24, 1), (0, 0.76), (0, 0.24)])
      case .triangle:
        return polygonContains(point, points: [(0.5, 0.04), (0.96, 0.96), (0.04, 0.96)])
      case .star:
        return polygonContains(point, points: [(0.5, 0.02), (0.61, 0.35), (0.96, 0.35), (0.68, 0.56), (0.79, 0.96), (0.5, 0.72), (0.21, 0.96), (0.32, 0.56), (0.04, 0.35), (0.39, 0.35)])
      case .pentagon:
        return polygonContains(point, points: [(0.5, 0.02), (0.98, 0.38), (0.8, 0.98), (0.2, 0.98), (0.02, 0.38)])
      case .spark:
        return polygonContains(point, points: [(0.5, 0), (0.62, 0.33), (1, 0.5), (0.62, 0.67), (0.5, 1), (0.38, 0.67), (0, 0.5), (0.38, 0.33)])
      }
    }

    private func capsuleContains(local point: CGPoint, frame: CGRect) -> Bool {
      let width = max(1, frame.width * bounds.width)
      let height = max(1, frame.height * bounds.height)
      let x = point.x * width
      let y = point.y * height
      let radius = min(width, height) / 2
      if width >= height {
        if x >= radius && x <= width - radius { return true }
        let centerX = x < radius ? radius : width - radius
        let dx = x - centerX
        let dy = y - radius
        return dx * dx + dy * dy <= radius * radius
      }
      if y >= radius && y <= height - radius { return true }
      let centerY = y < radius ? radius : height - radius
      let dx = x - radius
      let dy = y - centerY
      return dx * dx + dy * dy <= radius * radius
    }

    private func polygonContains(_ point: CGPoint, points: [(CGFloat, CGFloat)]) -> Bool {
      guard points.count > 2 else { return false }
      var inside = false
      var previous = points.count - 1
      for current in points.indices {
        let currentPoint = CGPoint(x: points[current].0, y: points[current].1)
        let previousPoint = CGPoint(x: points[previous].0, y: points[previous].1)
        let crosses = (currentPoint.y > point.y) != (previousPoint.y > point.y)
        if crosses {
          let x = (previousPoint.x - currentPoint.x) * (point.y - currentPoint.y) / max(0.0001, previousPoint.y - currentPoint.y) + currentPoint.x
          if point.x < x {
            inside.toggle()
          }
        }
        previous = current
      }
      return inside
    }
  }
}

private struct CustomSnapGridOverlay: View {
  let columns: Int
  let rows: Int
  let snapGrid: CustomSnapGrid?
  let flipped: Bool

  var body: some View {
    GeometryReader { proxy in
      let rect = gridRect(in: proxy.size)
      Path { path in
        let columnCount = max(1, columns)
        let rowCount = max(1, rows)
        for index in 0...columnCount {
          let x = rect.minX + rect.width * CGFloat(index) / CGFloat(columnCount)
          path.move(to: CGPoint(x: x, y: rect.minY))
          path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for index in 0...rowCount {
          let y = rect.minY + rect.height * CGFloat(index) / CGFloat(rowCount)
          path.move(to: CGPoint(x: rect.minX, y: y))
          path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
      }
      .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
      .overlay(
        Rectangle()
          .path(in: rect)
          .stroke(Color.white.opacity(0.38), lineWidth: 1.25)
      )
    }
  }

  private func gridRect(in size: CGSize) -> CGRect {
    let grid = (snapGrid ?? CustomSnapGrid()).normalized
    let x = flipped ? 1 - grid.x - grid.width : grid.x
    return CGRect(
      x: CGFloat(x) * size.width,
      y: CGFloat(grid.y) * size.height,
      width: CGFloat(grid.width) * size.width,
      height: CGFloat(grid.height) * size.height
    )
  }
}

private struct CustomEditableItemOverlay: View {
  @Binding var item: CustomItem
  let selected: Bool
  let areaSize: CGSize
  let snapToGrid: Bool
  let gridColumns: Int
  let gridRows: Int
  let snapGrid: CustomSnapGrid?
  let flipped: Bool
  let shape: PadShape
  let onSelect: () -> Void
  let onBeginEdit: () -> Void
  @State private var dragGrabOffset: CGSize?
  @State private var resizeStart: (width: Double, height: Double)?

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      PadShapePath(shape: shape)
        .fill(selected ? Color.white.opacity(0.08) : Color.white.opacity(0.001))
        .overlay(
          PadShapePath(shape: shape)
            .stroke(selected ? Color.white.opacity(0.9) : Color.white.opacity(0.28), style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: [5, 4]))
        )
        .contentShape(PadShapePath(shape: shape))
        .gesture(moveGesture)

      if selected {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
          .font(.caption.weight(.bold))
          .frame(width: 34, height: 34)
          .background(Color.white.opacity(0.18), in: Circle())
          .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
          .contentShape(Circle())
          .gesture(resizeGesture)
          .padding(4)
      }
    }
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  private var moveGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("CustomLayoutCanvas"))
      .onChanged { value in
        if dragGrabOffset == nil {
          onSelect()
          onBeginEdit()
          let displayX = flipped ? 1 - item.x - item.width : item.x
          dragGrabOffset = CGSize(
            width: value.startLocation.x - CGFloat(displayX) * areaSize.width,
            height: value.startLocation.y - CGFloat(item.y) * areaSize.height
          )
        }
        guard let dragGrabOffset else { return }
        let displayX = Double((value.location.x - dragGrabOffset.width) / max(1, areaSize.width))
        let nextY = Double((value.location.y - dragGrabOffset.height) / max(1, areaSize.height))
        let nextX = flipped ? 1 - displayX - item.width : displayX
        item.x = clamped(nextX, maxValue: 1 - item.width)
        item.y = clamped(nextY, maxValue: 1 - item.height)
      }
      .onEnded { _ in
        item.x = adjustedPosition(item.x, size: item.width, divisions: gridColumns, axis: .horizontal)
        item.y = adjustedPosition(item.y, size: item.height, divisions: gridRows, axis: .vertical)
        dragGrabOffset = nil
      }
  }

  private var resizeGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("CustomLayoutCanvas"))
      .onChanged { value in
        if resizeStart == nil {
          onSelect()
          onBeginEdit()
          resizeStart = (item.width, item.height)
        }
        guard let resizeStart else { return }
        let dw = Double(value.translation.width / max(1, areaSize.width))
        let dh = Double(value.translation.height / max(1, areaSize.height))
        item.width = clampedSize(resizeStart.width + dw, maxValue: 1 - item.x)
        item.height = clampedSize(resizeStart.height + dh, maxValue: 1 - item.y)
      }
      .onEnded { _ in
        item.width = adjustedSize(item.width, divisions: gridColumns, maxValue: 1 - item.x, axis: .horizontal)
        item.height = adjustedSize(item.height, divisions: gridRows, maxValue: 1 - item.y, axis: .vertical)
        resizeStart = nil
      }
  }

  private func clampedSize(_ value: Double, maxValue: Double) -> Double {
    min(max(0.05, value), max(0.05, maxValue))
  }

  private func clamped(_ value: Double, maxValue: Double) -> Double {
    min(max(0, value), max(0, maxValue))
  }

  private func adjusted(_ value: Double, divisions: Int, maxValue: Double) -> Double {
    let clamped = min(max(0, value), max(0, maxValue))
    guard snapToGrid, divisions > 0 else { return clamped }
    let step = 1.0 / Double(divisions)
    return min(max(0, (clamped / step).rounded() * step), max(0, maxValue))
  }

  private enum SnapAxis {
    case horizontal
    case vertical
  }

  private func adjustedPosition(_ value: Double, size: Double, divisions: Int, axis: SnapAxis) -> Double {
    let maxValue = 1 - size
    let clamped = min(max(0, value), max(0, maxValue))
    guard snapToGrid, divisions > 0 else { return clamped }

    let grid = (snapGrid ?? CustomSnapGrid()).normalized
    let origin = axis == .horizontal ? grid.x : grid.y
    let length = axis == .horizontal ? grid.width : grid.height
    let step = max(0.0001, length / Double(divisions))
    let visualValue = axis == .horizontal && flipped ? 1 - clamped - size : clamped
    let snappedVisual = origin + ((visualValue - origin) / step).rounded() * step
    let next = axis == .horizontal && flipped ? 1 - snappedVisual - size : snappedVisual
    return min(max(0, next), max(0, maxValue))
  }

  private func adjustedSize(_ value: Double, divisions: Int, maxValue: Double, axis: SnapAxis) -> Double {
    let clamped = min(max(0.05, value), max(0.05, maxValue))
    guard snapToGrid, divisions > 0 else { return clamped }
    let grid = (snapGrid ?? CustomSnapGrid()).normalized
    let length = axis == .horizontal ? grid.width : grid.height
    let step = max(0.0001, length / Double(divisions))
    return min(max(step, (clamped / step).rounded() * step), max(step, maxValue))
  }
}

private struct CustomEditorPanel: View {
  @ObservedObject var app: AppModel
  @Binding var selectedItemID: UUID?
  @Binding var visible: Bool
  @Binding var editMode: Bool
  @Binding var offset: CGSize
  let canUndo: Bool
  let canRedo: Bool
  @Binding var copiedItem: CustomItem?
  let onUndo: () -> Void
  let onRedo: () -> Void
  let onBeginEdit: () -> Void
  @State private var dragStart: CGSize?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      actionRow
      undoRedoRow
      Picker("Target", selection: $selectedItemID) {
        Text("None").tag(UUID?.none)
        ForEach(app.preset.customLayout.items) { item in
          Text(item.label.isEmpty ? item.kind.title : item.label).tag(Optional(item.id))
        }
      }
      .pickerStyle(.menu)

      Toggle("Edit layout", isOn: $editMode)
      Toggle("Snap", isOn: $app.preset.customLayout.snapToGrid)
      Toggle("Flip left/right", isOn: $app.preset.customLayout.flipHorizontal)
      Toggle("Show pad labels", isOn: $app.preset.customLayout.showLabels)
      DisclosureGroup("Snap grid") {
        snapGridControls
      }

      if let item = selectedItemBinding() {
        ScrollView {
          CustomEditorItemFields(
            app: app,
            item: item,
            onBeginEdit: onBeginEdit,
            onDuplicate: duplicateSelected,
            onDelete: deleteSelected
          )
        }
        .frame(maxHeight: 460)
      }
    }
    .padding(12)
    .frame(width: 390)
    .background(app.preset.theme.panel.color.opacity(0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.16), lineWidth: 1))
    .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    .offset(offset)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "line.3.horizontal")
        .font(.headline.weight(.semibold))
        .frame(width: 36, height: 28)
      Text(app.preset.customLayout.name)
        .font(.headline.weight(.semibold))
        .lineLimit(1)
      Spacer()
      Button {
        visible = false
      } label: {
        Image(systemName: "xmark")
          .frame(width: 32, height: 28)
      }
      .buttonStyle(.plain)
    }
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .named("CustomLayoutCanvas"))
        .onChanged { value in
          if dragStart == nil {
            dragStart = offset
          }
          guard let dragStart else { return }
          offset = CGSize(
            width: dragStart.width + value.translation.width,
            height: dragStart.height + value.translation.height
          )
        }
        .onEnded { _ in
          dragStart = nil
        }
    )
  }

  private var actionRow: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Menu {
          Button { add(.note) } label: { Label("Note", systemImage: "plus.square") }
          Button { add(.ccSliderX) } label: { Label("Slider H", systemImage: "slider.horizontal.2.square") }
          Button { add(.ccSliderY) } label: { Label("Slider V", systemImage: "slider.vertical.3") }
          Button { add(.label) } label: { Label("Label", systemImage: "textformat") }
          Button { add(.sustain) } label: { Label("Sustain", systemImage: "pause.rectangle") }
          Button { add(.panic) } label: { Label("Panic", systemImage: "stop.circle") }
          Button { add(.image) } label: { Label("Image", systemImage: "photo") }
          Button { add(.video) } label: { Label("Video", systemImage: "video") }
          Button { add(.keyCommand) } label: { Label("Key", systemImage: "keyboard") }
        } label: {
          panelLabel("plus.square", "Add")
        }
        .buttonStyle(.bordered)

        panelButton("doc.on.doc", "Copy") {
          copySelected()
        }
        .disabled(selectedItemID == nil)

        panelButton("doc.on.clipboard", "Paste") {
          pasteCopied()
        }
        .disabled(copiedItem == nil)

        panelButton("trash", "Clear") { clearAll() }
      }

      HStack(spacing: 8) {
        panelButton("guitars", "Fretboard") {
          loadFactory(.editableFretboard)
        }
        panelButton("drum", "Drumset") {
          loadFactory(.editableDrumset)
        }
        panelButton("square.grid.3x3", "Blank Grid") {
          loadFactory(.blankGrid)
        }
      }
    }
  }

  private var snapGridControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      Stepper("Columns \(app.preset.customLayout.gridColumns)", value: $app.preset.customLayout.gridColumns, in: 2...64)
      Stepper("Rows \(app.preset.customLayout.gridRows)", value: $app.preset.customLayout.gridRows, in: 2...64)
      gridSlider("X", keyPath: \.x, range: 0...0.95)
      gridSlider("Y", keyPath: \.y, range: 0...0.95)
      gridSlider("Width", keyPath: \.width, range: 0.05...1)
      gridSlider("Height", keyPath: \.height, range: 0.05...1)
      HStack {
        Button("Full screen") {
          onBeginEdit()
          app.preset.customLayout.snapGrid = CustomSnapGrid(x: 0, y: 0, width: 1, height: 1)
        }
        Button("Fit items") {
          fitGridToItems()
        }
      }
      .buttonStyle(.bordered)
    }
  }

  private func gridSlider(_ title: String, keyPath: WritableKeyPath<CustomSnapGrid, Double>, range: ClosedRange<Double>) -> some View {
    let value = snapGridBinding(keyPath)
    return VStack(alignment: .leading, spacing: 4) {
      Text("\(title) \(Int((value.wrappedValue * 100).rounded()))%")
        .font(.caption)
      Slider(value: value, in: range)
    }
  }

  private func snapGridBinding(_ keyPath: WritableKeyPath<CustomSnapGrid, Double>) -> Binding<Double> {
    Binding {
      (app.preset.customLayout.snapGrid ?? CustomSnapGrid())[keyPath: keyPath]
    } set: { newValue in
      onBeginEdit()
      var grid = app.preset.customLayout.snapGrid ?? CustomSnapGrid()
      grid[keyPath: keyPath] = newValue
      app.preset.customLayout.snapGrid = grid.normalized
    }
  }

  private func fitGridToItems() {
    onBeginEdit()
    let items = app.preset.customLayout.items
    guard !items.isEmpty else {
      app.preset.customLayout.snapGrid = CustomSnapGrid(x: 0, y: 0, width: 1, height: 1)
      return
    }
    let minX = max(0, items.map(\.x).min() ?? 0)
    let minY = max(0, items.map(\.y).min() ?? 0)
    let maxX = min(1, items.map { $0.x + $0.width }.max() ?? 1)
    let maxY = min(1, items.map { $0.y + $0.height }.max() ?? 1)
    app.preset.customLayout.snapGrid = CustomSnapGrid(
      x: minX,
      y: minY,
      width: max(0.05, maxX - minX),
      height: max(0.05, maxY - minY)
    ).normalized
  }

  private func loadFactory(_ layout: CustomLayout) {
    onBeginEdit()
    app.preset.customLayout = layout
    selectedItemID = app.preset.customLayout.items.first?.id
    editMode = true
  }

  private var undoRedoRow: some View {
    HStack(spacing: 8) {
      Button(action: onUndo) {
        Label("Undo", systemImage: "arrow.uturn.backward")
          .frame(maxWidth: .infinity, minHeight: 30)
      }
      .disabled(!canUndo)

      Button(action: onRedo) {
        Label("Redo", systemImage: "arrow.uturn.forward")
          .frame(maxWidth: .infinity, minHeight: 30)
      }
      .disabled(!canRedo)
    }
    .buttonStyle(.bordered)
  }

  private func panelButton(_ image: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      panelLabel(image, label)
    }
    .buttonStyle(.bordered)
  }

  private func panelLabel(_ image: String, _ label: String) -> some View {
    Label(label, systemImage: image)
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .frame(maxWidth: .infinity, minHeight: 34)
  }

  private func selectedItemBinding() -> Binding<CustomItem>? {
    guard let selectedItemID else { return nil }
    return Binding(
      get: {
        app.preset.customLayout.items.first { $0.id == selectedItemID } ?? CustomItem()
      },
      set: { newValue in
        guard let index = app.preset.customLayout.items.firstIndex(where: { $0.id == selectedItemID }) else { return }
        app.preset.customLayout.items[index] = newValue
      }
    )
  }

  private func add(_ kind: CustomItemKind) {
    onBeginEdit()
    var item = CustomItem()
    item.kind = kind
    item.label = defaultLabel(for: kind)
    item.shape = app.preset.theme.shape
    item.x = 0.38
    item.y = 0.34
    switch kind {
    case .note:
      item.width = 0.16
      item.height = 0.18
      item.note = 12 * (app.preset.baseOctave + 1) + app.preset.rootNote
      item.channel = app.preset.midiChannel
    case .ccSliderX:
      item.width = 0.34
      item.height = 0.12
      item.cc = app.preset.cc1Number
    case .ccSliderY:
      item.width = 0.12
      item.height = 0.34
      item.cc = app.preset.cc1Number
    case .label:
      item.width = 0.24
      item.height = 0.1
    case .sustain, .panic:
      item.width = 0.2
      item.height = 0.13
    case .image:
      item.width = 0.24
      item.height = 0.24
      item.shape = .rounded
    case .video:
      item.width = 0.34
      item.height = 0.24
      item.shape = .rounded
    case .keyCommand:
      item.width = 0.16
      item.height = 0.13
      item.keyCommand = "ArrowLeft"
      item.label = "Left"
    }
    app.preset.customLayout.items.append(item)
    selectedItemID = item.id
    editMode = true
  }

  private func defaultLabel(for kind: CustomItemKind) -> String {
    switch kind {
    case .note: return "Pad"
    case .ccSliderX: return "CC H"
    case .ccSliderY: return "CC V"
    case .label: return "Label"
    case .sustain: return "Sustain"
    case .panic: return "Panic"
    case .image: return "Image"
    case .video: return "Video"
    case .keyCommand: return "Key"
    }
  }

  private func duplicateSelected() {
    guard let selectedItemID,
          let item = app.preset.customLayout.items.first(where: { $0.id == selectedItemID }) else { return }
    onBeginEdit()
    var copy = item
    copy.id = UUID()
    copy.x = min(1 - copy.width, copy.x + 0.04)
    copy.y = min(1 - copy.height, copy.y + 0.04)
    app.preset.customLayout.items.append(copy)
    self.selectedItemID = copy.id
    editMode = true
  }

  private func copySelected() {
    guard let selectedItemID,
          let item = app.preset.customLayout.items.first(where: { $0.id == selectedItemID }) else { return }
    copiedItem = item
  }

  private func pasteCopied() {
    guard var item = copiedItem else { return }
    onBeginEdit()
    item.id = UUID()
    item.x = min(1 - item.width, item.x + 0.04)
    item.y = min(1 - item.height, item.y + 0.04)
    app.preset.customLayout.items.append(item)
    selectedItemID = item.id
    editMode = true
  }

  private func deleteSelected() {
    guard let selectedItemID,
          let index = app.preset.customLayout.items.firstIndex(where: { $0.id == selectedItemID }) else { return }
    onBeginEdit()
    app.release(item: app.preset.customLayout.items[index])
    app.preset.customLayout.items.remove(at: index)
    self.selectedItemID = app.preset.customLayout.items.first?.id
  }

  private func clearAll() {
    onBeginEdit()
    app.releaseAll()
    app.preset.customLayout.items.removeAll()
    selectedItemID = nil
  }
}

private struct CustomEditorItemFields: View {
  @ObservedObject var app: AppModel
  @Binding var item: CustomItem
  let onBeginEdit: () -> Void
  let onDuplicate: () -> Void
  let onDelete: () -> Void
  @State private var imagePickerItem: PhotosPickerItem?
  @State private var activeImagePickerItem: PhotosPickerItem?
  @State private var videoPickerItem: PhotosPickerItem?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Label", text: $item.label)
        .textFieldStyle(.roundedBorder)

      Picker("Type", selection: $item.kind) {
        ForEach(CustomItemKind.allCases) { kind in
          Text(kind.title).tag(kind)
        }
      }
      .pickerStyle(.menu)

      if item.kind == .note {
        Stepper("Note \(item.note)", value: $item.note, in: 0...127)
        Stepper("Channel \(item.channel)", value: $item.channel, in: 1...16)
      }

      if item.kind == .ccSliderX || item.kind == .ccSliderY {
        Stepper("CC \(item.cc)", value: $item.cc, in: 0...127)
        Stepper("Value \(item.value)", value: $item.value, in: 0...127)
      }

      if item.kind == .keyCommand {
        Stepper("CC \(item.cc)", value: $item.cc, in: 0...127)
        Stepper("Press value \(item.value)", value: $item.value, in: 64...127)
        Picker("Key", selection: $item.keyCommand) {
          Text("Left").tag("ArrowLeft")
          Text("Right").tag("ArrowRight")
          Text("Up").tag("ArrowUp")
          Text("Down").tag("ArrowDown")
          Text("I").tag("i")
          Text("Space").tag("Space")
          Text("Enter").tag("Enter")
        }
        .pickerStyle(.segmented)
        TextField("Custom key name", text: $item.keyCommand)
          .textFieldStyle(.roundedBorder)
        Text("Key pads are available to in-app integrations. iPadOS does not allow this app to synthesize hardware keypresses into another app.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if item.kind == .image || item.kind == .video || item.kind == .note || item.kind == .sustain || item.kind == .panic {
        mediaControls
      }

      Picker("Shape", selection: $item.shape) {
        ForEach(PadShape.allCases) { shape in
          Text(shape.title).tag(shape)
        }
      }
      .pickerStyle(.menu)

      HStack(spacing: 6) {
        moveButton("arrow.left", dx: -moveStepX, dy: 0)
        moveButton("arrow.up", dx: 0, dy: -moveStepY)
        moveButton("arrow.down", dx: 0, dy: moveStepY)
        moveButton("arrow.right", dx: moveStepX, dy: 0)
      }

      compactSlider("X", value: binding(\.x, maxValue: 1 - item.width))
      compactSlider("Y", value: binding(\.y, maxValue: 1 - item.height))
      compactSlider("W", value: sizeBinding(\.width, pairedPosition: \.x), range: 0.05...0.9)
      compactSlider("H", value: sizeBinding(\.height, pairedPosition: \.y), range: 0.05...0.9)
      compactSlider("Text", value: doubleBinding(\.labelSize, range: 12...96), range: 12...96)
      compactSlider("Rotate", value: doubleBinding(\.rotation, range: -180...180), range: -180...180)

      HStack(spacing: 8) {
        Button(action: onDuplicate) {
          Label("Copy", systemImage: "doc.on.doc")
            .frame(maxWidth: .infinity)
        }
        Button(role: .destructive, action: onDelete) {
          Label("Delete", systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.bordered)
    }
    .font(.caption)
    .onChange(of: imagePickerItem) { _, newItem in
      loadMedia(from: newItem) { data in
        onBeginEdit()
        item.imageData = data
        if item.kind == .label {
          item.kind = .image
        }
      }
    }
    .onChange(of: activeImagePickerItem) { _, newItem in
      loadMedia(from: newItem) { data in
        onBeginEdit()
        item.activeImageData = data
      }
    }
    .onChange(of: videoPickerItem) { _, newItem in
      loadMedia(from: newItem) { data in
        onBeginEdit()
        item.videoData = data
        item.kind = .video
      }
    }
  }

  private var mediaControls: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        PhotosPicker(selection: $imagePickerItem, matching: .images) {
          Label(item.imageData == nil ? "Image" : "Replace image", systemImage: "photo")
            .frame(maxWidth: .infinity)
        }

        PhotosPicker(selection: $activeImagePickerItem, matching: .images) {
          Label(item.activeImageData == nil ? "Active" : "Replace active", systemImage: "photo.on.rectangle")
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.bordered)

      HStack(spacing: 8) {
        PhotosPicker(selection: $videoPickerItem, matching: .videos) {
          Label(item.videoData == nil ? "Video" : "Replace video", systemImage: "video")
            .frame(maxWidth: .infinity)
        }

        Button {
          onBeginEdit()
          item.imageData = nil
          item.activeImageData = nil
          item.videoData = nil
        } label: {
          Label("Clear media", systemImage: "xmark.circle")
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.bordered)
    }
  }

  private var moveStepX: Double {
    app.preset.customLayout.snapToGrid ? 1.0 / Double(max(1, app.preset.customLayout.gridColumns)) : 0.01
  }

  private var moveStepY: Double {
    app.preset.customLayout.snapToGrid ? 1.0 / Double(max(1, app.preset.customLayout.gridRows)) : 0.01
  }

  private func moveButton(_ image: String, dx: Double, dy: Double) -> some View {
    Button {
      item.x = adjusted(item.x + dx, divisions: app.preset.customLayout.gridColumns, maxValue: 1 - item.width)
      item.y = adjusted(item.y + dy, divisions: app.preset.customLayout.gridRows, maxValue: 1 - item.height)
    } label: {
      Image(systemName: image)
        .frame(maxWidth: .infinity, minHeight: 30)
    }
    .buttonStyle(.bordered)
  }

  private func compactSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
    HStack(spacing: 8) {
      Text(title)
        .frame(width: 42, alignment: .leading)
      Slider(value: value, in: range)
      Text(String(format: "%.2f", value.wrappedValue))
        .monospacedDigit()
        .frame(width: 44, alignment: .trailing)
    }
  }

  private func binding(_ keyPath: WritableKeyPath<CustomItem, Double>, maxValue: Double) -> Binding<Double> {
    Binding(
      get: { item[keyPath: keyPath] },
      set: { newValue in
        let divisions = keyPath == \CustomItem.x ? app.preset.customLayout.gridColumns : app.preset.customLayout.gridRows
        item[keyPath: keyPath] = adjusted(newValue, divisions: divisions, maxValue: maxValue)
      }
    )
  }

  private func sizeBinding(_ keyPath: WritableKeyPath<CustomItem, Double>, pairedPosition: WritableKeyPath<CustomItem, Double>) -> Binding<Double> {
    Binding(
      get: { item[keyPath: keyPath] },
      set: { newValue in
        item[keyPath: keyPath] = min(max(0.05, newValue), 0.9)
        item[keyPath: pairedPosition] = min(item[keyPath: pairedPosition], 1 - item[keyPath: keyPath])
      }
    )
  }

  private func doubleBinding(_ keyPath: WritableKeyPath<CustomItem, Double>, range: ClosedRange<Double>) -> Binding<Double> {
    Binding(
      get: { item[keyPath: keyPath] },
      set: { newValue in
        item[keyPath: keyPath] = min(max(range.lowerBound, newValue), range.upperBound)
      }
    )
  }

  private func adjusted(_ value: Double, divisions: Int, maxValue: Double) -> Double {
    let clamped = min(max(0, value), max(0, maxValue))
    guard app.preset.customLayout.snapToGrid, divisions > 0 else { return clamped }
    let step = 1.0 / Double(divisions)
    return min(max(0, (clamped / step).rounded() * step), max(0, maxValue))
  }

  private func loadMedia(from pickerItem: PhotosPickerItem?, assign: @escaping (Data) -> Void) {
    guard let pickerItem else { return }
    Task {
      if let data = try? await pickerItem.loadTransferable(type: Data.self) {
        await MainActor.run {
          assign(data)
        }
      }
    }
  }
}

private struct CustomItemControl: View {
  @ObservedObject var app: AppModel
  @Binding var item: CustomItem
  let showLabels: Bool
  @State private var isTouching = false

  var body: some View {
    switch item.kind {
    case .note:
      noteView
    case .ccSliderX, .ccSliderY:
      sliderView
    case .label:
      Text(showLabels ? item.label : "")
        .font(.headline.weight(.semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.55)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .sustain:
      buttonView(active: app.sustainButtonActive)
    case .panic:
      buttonView(active: false)
    case .keyCommand:
      buttonView(active: isTouching)
    case .image:
      imageView
    case .video:
      videoView
    }
  }

  private var noteView: some View {
    let active = app.isActive(note: item.note, channel: item.channel) || isTouching
    return PadChrome(
      title: showLabels ? item.label : "",
      subtitle: showLabels && app.preset.theme.showNoteNames ? MusicTheory.noteName(item.note) : "",
      shape: item.shape,
      active: active,
      fill: customFill(active: active),
      border: customBorder(active: active),
      glowColor: customGlow(active: active),
      glow: app.preset.theme.glowOnTouch,
      imageData: active ? (item.activeImageData ?? item.imageData) : item.imageData,
      labelSize: item.labelSize,
      rotation: item.rotation
    )
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          guard !isTouching else { return }
          isTouching = true
          app.press(item: item)
        }
        .onEnded { _ in
          isTouching = false
          app.release(item: item)
        }
    )
  }

  private var sliderView: some View {
    GeometryReader { proxy in
      let ratio = Double(item.value) / 127.0
      ZStack(alignment: item.kind == .ccSliderX ? .leading : .bottom) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(item.fill.color.opacity(0.35))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16), lineWidth: 1))

        if item.kind == .ccSliderX {
          RoundedRectangle(cornerRadius: 12)
            .fill(item.activeFill.color)
            .frame(width: proxy.size.width * ratio)
        } else {
          RoundedRectangle(cornerRadius: 12)
            .fill(item.activeFill.color)
            .frame(height: proxy.size.height * ratio)
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let ratio: Double
            if item.kind == .ccSliderX {
              ratio = max(0, min(1, value.location.x / max(1, proxy.size.width)))
            } else {
              ratio = 1 - max(0, min(1, value.location.y / max(1, proxy.size.height)))
            }
            item.value = Int((ratio * 127).rounded())
            app.setCC(item: item, value: item.value)
          }
      )
    }
  }

  private func buttonView(active: Bool) -> some View {
    PadChrome(
      title: showLabels ? item.label : "",
      subtitle: "",
      shape: item.shape,
      active: active,
      fill: customFill(active: active),
      border: customBorder(active: active),
      glowColor: customGlow(active: active),
      glow: app.preset.theme.glowOnTouch,
      imageData: active ? (item.activeImageData ?? item.imageData) : item.imageData,
      labelSize: item.labelSize,
      rotation: item.rotation
    )
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          guard !isTouching else { return }
          isTouching = true
          app.press(item: item)
        }
        .onEnded { _ in
          isTouching = false
          app.release(item: item)
        }
    )
  }

  private var imageView: some View {
    PadChrome(
      title: showLabels && item.imageData == nil ? item.label : "",
      subtitle: "",
      shape: item.shape,
      active: false,
      fill: item.fill.color,
      border: customBorder(active: false),
      glowColor: customGlow(active: false),
      glow: app.preset.theme.glowOnTouch,
      imageData: item.imageData,
      labelSize: item.labelSize,
      rotation: item.rotation
    )
  }

  private var videoView: some View {
    ZStack {
      if let data = item.videoData {
        VideoDataPlayer(data: data)
          .clipShape(PadShapePath(shape: item.shape))
      } else {
        PadChrome(
          title: showLabels ? item.label : "",
          subtitle: showLabels ? "Video" : "",
          shape: item.shape,
          active: false,
          fill: item.fill.color,
          border: customBorder(active: false),
          glowColor: customGlow(active: false),
          glow: app.preset.theme.glowOnTouch,
          imageData: item.imageData,
          labelSize: item.labelSize,
          rotation: item.rotation
        )
      }

      PadShapePath(shape: item.shape)
        .stroke(customBorder(active: false), lineWidth: 2)
    }
  }

  private var customRow: Int {
    Int((item.y * 7).rounded())
  }

  private func customFill(active: Bool) -> Color {
    guard app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift else {
      return active ? item.activeFill.color : item.fill.color
    }
    return active ? themedActiveFillColor(app.preset.theme, row: customRow, maxRow: 7) : themedGradientColor(app.preset.theme, row: customRow, maxRow: 7)
  }

  private func customBorder(active: Bool) -> Color {
    guard app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift else {
      return active ? app.preset.theme.activeGlow.color : app.preset.theme.padBorder.color
    }
    return active ? themedActiveGlowColor(app.preset.theme, row: customRow, maxRow: 7) : themedBorderColor(app.preset.theme, row: customRow, maxRow: 7)
  }

  private func customGlow(active: Bool) -> Color {
    guard app.preset.theme.colorMode == "gradient" || app.preset.theme.hueShift else {
      return active ? app.preset.theme.activeGlow.color : app.preset.theme.padGlow.color
    }
    return active ? themedActiveGlowColor(app.preset.theme, row: customRow, maxRow: 7) : themedGlowColor(app.preset.theme, row: customRow, maxRow: 7)
  }
}

private struct VideoDataPlayer: View {
  let data: Data
  @State private var player: AVPlayer?
  @State private var observer: NSObjectProtocol?

  var body: some View {
    Group {
      if let player {
        VideoPlayer(player: player)
          .disabled(true)
      } else {
        Color.black
      }
    }
    .onAppear {
      loadPlayer()
    }
    .onDisappear {
      if let observer {
        NotificationCenter.default.removeObserver(observer)
      }
      player?.pause()
      player = nil
    }
  }

  private func loadPlayer() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("midivana-\(UUID().uuidString)")
      .appendingPathExtension("mov")
    do {
      try data.write(to: url, options: .atomic)
      let nextPlayer = AVPlayer(url: url)
      observer = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: nextPlayer.currentItem,
        queue: .main
      ) { _ in
        nextPlayer.seek(to: .zero)
        nextPlayer.play()
      }
      player = nextPlayer
      nextPlayer.isMuted = true
      nextPlayer.play()
    } catch {
      player = nil
    }
  }
}
