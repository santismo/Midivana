import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published var preset: AppPreset = .default {
    didSet {
      if oldValue.midiChannel != preset.midiChannel {
        releaseAll()
      }
      syncMotion()
      syncVibrato()
    }
  }
  @Published var selectedOutputID: Int32?
  @Published var selectedInputID: Int32? {
    didSet {
      midi.selectInput(selectedInputID)
    }
  }
  @Published private(set) var activeNotes = Set<ActiveNote>()
  @Published private(set) var heldSustainNotes = Set<ActiveNote>()
  @Published private(set) var lastSentVelocity = 0
  @Published private(set) var lastKeyCommand = ""
  @Published private(set) var activeKeyPadIDs = Set<UUID>()
  @Published var sustainButtonActive = false {
    didSet {
      if !sustainButtonActive {
        releaseSustainedNotes()
      }
    }
  }

  let midi = MIDIService()
  let motion = MotionService()
  let presetStore = PresetStore()

  private var vibratoTimer: Timer?
  private var vibratoPhase = 0.0
  private var activeNoteCounts: [ActiveNote: Int] = [:]
  private var activeNoteVelocities: [ActiveNote: Int] = [:]
  private var layoutChangeInFlight = false
  private var midiOutputsCancellable: AnyCancellable?

  init() {
    preset = presetStore.presets.first ?? .default
    if preset.theme.rowGap == 3 {
      preset.theme.rowGap = 7
    }
    if preset.accelSensitivity == 1.6 {
      preset.accelSensitivity = 2.0
    }
    if preset.touchForceSensitivity == 0.35 {
      preset.touchForceSensitivity = 0.0
    }
    if preset.accelMax == 0.8 {
      preset.accelMax = 1.0
    }
    if preset.theme.markerOffset == -18 {
      preset.theme.markerOffset = -80
    }
    if preset.quickCCNumbers.isEmpty {
      preset.quickCCNumbers = [preset.cc1Number, preset.cc2Number]
    }
    if preset.quickCCVisibleCount == 1 && preset.cc2Visible {
      preset.quickCCVisibleCount = 2
    }
    if !UserDefaults.standard.bool(forKey: "MidivanaMacKeyPadsUserConfigured") && !preset.showMacKeyPads {
      preset.showMacKeyPads = true
    }
    preset.keyPadEditMode = false
    if preset.keyPads.isEmpty {
      resetKeyPadsToDefaultRow()
    } else {
      preset.keyPads = preset.keyPads.map(\.normalized)
    }
    motion.valueHandler = { [weak self] value in
      Task { @MainActor in
        self?.sendMotionValue(value)
      }
    }
    midiOutputsCancellable = midi.$outputs
      .sink { [weak self] outputs in
        Task { @MainActor in
          self?.autoSelectPreferredOutput(from: outputs)
        }
      }
    syncMotion()
  }

  var currentPads: [[NotePad]] {
    switch preset.layout {
    case .fretboard:
      return MusicTheory.fretboardPads(for: preset)
    case .keyboard:
      return MusicTheory.keyboardPads(for: preset)
    case .drums:
      return MusicTheory.drumPads(for: preset)
    case .custom:
      return []
    }
  }

  func refreshMIDI() {
    midi.refreshEndpoints()
  }

  private func autoSelectPreferredOutput(from outputs: [MIDIEndpointInfo]) {
    if let selectedOutputID, outputs.contains(where: { $0.id == selectedOutputID }) {
      return
    }
    selectedOutputID = preferredOutputID(in: outputs)
  }

  private func preferredOutputID(in outputs: [MIDIEndpointInfo]) -> Int32? {
    let preferredNames = ["idam midi host", "idam", "qwerty-fretboard control", "qwerty", "ipad", "iphone"]
    for preferredName in preferredNames {
      if let match = outputs.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
        return match.id
      }
    }
    return nil
  }

  func setLayout(_ layout: PerformanceLayout) {
    guard preset.layout != layout, !layoutChangeInFlight else { return }
    layoutChangeInFlight = true
    releaseForLayoutChange()
    preset.layout = layout
    finishLayoutChangeSoon()
  }

  func setCustomLayout(_ layout: CustomLayout) {
    guard !layoutChangeInFlight else { return }
    layoutChangeInFlight = true
    releaseForLayoutChange()
    preset.customLayout = layout
    preset.layout = .custom
    finishLayoutChangeSoon()
  }

  private func finishLayoutChangeSoon() {
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 180_000_000)
      self?.layoutChangeInFlight = false
    }
  }

  func isActive(note: Int, channel: Int) -> Bool {
    activeNotes.contains(ActiveNote(note: note, channel: channel))
      || midi.externalActiveNotes.contains(ActiveNote(note: note, channel: channel))
  }

  func isControlActive(controller: Int, channel: Int) -> Bool {
    midi.externalActiveControls.contains(ActiveControl(controller: controller, channel: channel))
  }

  func press(_ pad: NotePad, touchIntensity: Double? = nil) {
    press(note: pad.note, channel: pad.channel, touchIntensity: touchIntensity)
  }

  func release(_ pad: NotePad) {
    release(note: pad.note, channel: pad.channel)
  }

  func press(item: CustomItem) {
    switch item.kind {
    case .note:
      press(note: item.note, channel: item.channel)
    case .sustain:
      beginSustainControl()
    case .panic:
      releaseAll()
    case .keyCommand:
      sendKeyCommand(item.keyCommand)
      setCC(item: item, value: max(64, item.value))
    case .ccSliderX, .ccSliderY, .label, .image, .video:
      break
    }
  }

  func release(item: CustomItem) {
    switch item.kind {
    case .note:
      release(note: item.note, channel: item.channel)
    case .sustain:
      endSustainControl()
    case .keyCommand:
      setCC(item: item, value: 0)
    case .panic, .ccSliderX, .ccSliderY, .label, .image, .video:
      break
    }
  }

  func setCC(item: CustomItem, value: Int) {
    midi.sendControlChange(
      controller: item.cc,
      value: value.clamped(to: 0...127),
      channel: item.channel,
      outputID: selectedOutputID
    )
  }

  func setQuickCC(number: Int, value: Int) {
    midi.sendControlChange(
      controller: number,
      value: value.clamped(to: 0...127),
      channel: preset.midiChannel,
      outputID: selectedOutputID
    )
  }

  func setKeyPadCC(number: Int, pressed: Bool) {
    sendKeyPadControlChange(controller: number, value: pressed ? preset.keyPadPressValue.clamped(to: 64...127) : 0)
  }

  func setKeyPad(_ keyPad: MacKeyPad, pressed: Bool) {
    let normalized = keyPad.normalized
    if pressed {
      activeKeyPadIDs.insert(normalized.id)
    } else {
      activeKeyPadIDs.remove(normalized.id)
    }
    sendKeyPadControlChange(controller: normalized.cc, value: pressed ? normalized.pressValue : 0)
  }

  func beginKeyPad(_ keyPad: MacKeyPad) {
    guard !preset.keyPadEditMode, !activeKeyPadIDs.contains(keyPad.id) else { return }
    setKeyPad(keyPad, pressed: true)
  }

  func endKeyPad(_ keyPad: MacKeyPad) {
    guard activeKeyPadIDs.contains(keyPad.id) else { return }
    setKeyPad(keyPad, pressed: false)
  }

  func setKeyPadEditMode(_ enabled: Bool) {
    guard preset.keyPadEditMode != enabled else { return }
    if enabled {
      releaseActiveKeyPads()
    }
    preset.keyPadEditMode = enabled
    preset.keyPads = preset.keyPads.map(\.normalized)
    if !enabled {
      updateCurrentPreset()
    }
  }

  func addKeyPad() {
    let count = preset.keyPads.count
    let column = count % 5
    let row = (count / 5) % 3
    let next = MacKeyPad(
      label: "K\(count + 1)",
      cc: nextAvailableKeyPadCC(),
      pressValue: preset.keyPadPressValue,
      x: 0.05 + Double(column) * 0.18,
      y: 0.18 + Double(row) * 0.24,
      width: 0.15,
      height: 0.52
    ).normalized
    preset.keyPads.append(next)
  }

  func duplicateKeyPad(_ keyPad: MacKeyPad) {
    var copy = keyPad.normalized
    copy.id = UUID()
    copy.x = min(1 - copy.width, copy.x + 0.04)
    copy.y = min(1 - copy.height, copy.y + 0.04)
    preset.keyPads.append(copy)
  }

  func deleteKeyPad(_ keyPad: MacKeyPad) {
    preset.keyPads.removeAll { $0.id == keyPad.id }
  }

  func deleteKeyPad(id: UUID) {
    preset.keyPads.removeAll { $0.id == id }
  }

  func deleteLastKeyPad() {
    _ = preset.keyPads.popLast()
  }

  func resetKeyPadsToDefaultRow() {
    preset.keyPadCCLeft = 80
    preset.keyPadCCRight = 81
    preset.keyPadCCDown = 83
    preset.keyPadCCUp = 82
    preset.keyPadCCI = 84
    preset.keyPads = MacKeyPad.defaultRow(
      leftCC: preset.keyPadCCLeft,
      rightCC: preset.keyPadCCRight,
      downCC: preset.keyPadCCDown,
      upCC: preset.keyPadCCUp,
      iCC: preset.keyPadCCI,
      pressValue: preset.keyPadPressValue
    )
  }

  private func releaseActiveKeyPads() {
    let activeIDs = activeKeyPadIDs
    for keyPad in preset.keyPads where activeIDs.contains(keyPad.id) {
      setKeyPad(keyPad, pressed: false)
    }
    activeKeyPadIDs.removeAll()
  }

  private func sendKeyPadControlChange(controller: Int, value: Int) {
    let selectedID = selectedOutputID
    midi.sendControlChange(
      controller: controller,
      value: value,
      channel: preset.midiChannel,
      outputID: selectedID
    )
    guard let qwertyID = qwertyFretboardOutputID(), qwertyID != selectedID else { return }
    midi.sendControlChange(
      controller: controller,
      value: value,
      channel: preset.midiChannel,
      outputID: qwertyID
    )
  }

  private func qwertyFretboardOutputID() -> Int32? {
    midi.outputs.first { output in
      let name = output.name.lowercased()
      return name.contains("qwerty-fretboard control")
        || name.contains("qwerty fretboard control")
        || name.contains("qwerty")
    }?.id
  }

  func bend(_ amount: Double, channel: Int) {
    guard preset.pitchBendEnabled else { return }
    midi.sendPitchBend(normalized: amount, channel: channel, outputID: selectedOutputID)
  }

  func resetBend(channel: Int) {
    midi.resetPitchBend(channel: channel, outputID: selectedOutputID)
  }

  func releaseAll(sendGlobalReset: Bool = true) {
    releaseActiveKeyPads()
    let notesToRelease = activeNotes
    let channelsToReset = Set(notesToRelease.map(\.channel))
    for active in notesToRelease {
      midi.sendNoteOff(note: active.note, channel: active.channel, outputID: selectedOutputID)
    }
    for channel in channelsToReset {
      midi.resetPitchBend(channel: channel, outputID: selectedOutputID)
    }
    activeNotes.removeAll()
    activeNoteCounts.removeAll()
    activeNoteVelocities.removeAll()
    heldSustainNotes.removeAll()
    sustainButtonActive = false
    if sendGlobalReset {
      for channel in 1...16 {
        midi.sendAllNotesOff(channel: channel, outputID: selectedOutputID)
      }
    }
    stopVibrato()
  }

  private func releaseForLayoutChange() {
    let notesToRelease = activeNotes
    let channelsToReset = Set(notesToRelease.map(\.channel))
    for active in notesToRelease {
      midi.sendNoteOff(note: active.note, channel: active.channel, outputID: selectedOutputID)
    }
    for channel in channelsToReset {
      midi.resetPitchBend(channel: channel, outputID: selectedOutputID)
    }
    activeNotes.removeAll()
    activeNoteCounts.removeAll()
    activeNoteVelocities.removeAll()
    heldSustainNotes.removeAll()
    sustainButtonActive = false
    stopVibrato()
  }

  private func nextAvailableKeyPadCC() -> Int {
    let used = Set(preset.keyPads.map(\.cc))
    for cc in 80...127 where !used.contains(cc) {
      return cc
    }
    return 80
  }

  func beginSustainControl() {
    switch preset.sustainMode {
    case .momentary, .hold:
      sustainButtonActive = true
    case .latch:
      sustainButtonActive.toggle()
    }
  }

  func endSustainControl() {
    if preset.sustainMode == .hold || preset.sustainMode == .momentary {
      sustainButtonActive = false
    }
  }

  func saveCurrentPreset(named name: String) {
    var saved = preset
    saved.id = UUID()
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    saved.name = cleanName.isEmpty ? "Untitled" : cleanName
    presetStore.upsert(saved)
    preset = saved
  }

  func updateCurrentPreset(named name: String? = nil) {
    if let name {
      let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if !cleanName.isEmpty {
        preset.name = cleanName
      }
    }
    presetStore.upsert(preset)
  }

  func addCurrentPresetToQuickLayoutMenu() {
    updateCurrentPreset()
    presetStore.addToQuickLayoutMenu(preset)
  }

  func renameSavedPreset(id: UUID, to name: String) {
    presetStore.rename(id, to: name)
    if preset.id == id {
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        preset.name = trimmed
      }
    }
  }

  func apply(_ savedPreset: AppPreset) {
    releaseAll()
    preset = savedPreset
  }

  func delete(_ savedPreset: AppPreset) {
    presetStore.delete(savedPreset)
    if preset.id == savedPreset.id {
      preset = presetStore.presets.first ?? .default
    }
  }

  func importPresetData(_ data: Data) throws {
    let imported = try presetStore.importData(data)
    apply(imported)
  }

  func exportCurrentPresetData() throws -> Data {
    try presetStore.exportData(for: preset)
  }

  func randomizeColorsForHueBlend() {
    preset.theme.colorMode = "gradient"
    preset.theme.hueShift = true
    preset.theme.hueShiftAmount = Double.random(in: 180...540)
    preset.theme.hueShiftSpeed = Double.random(in: 5...18)
    preset.theme.background = CodableColor.random(darker: true)
    preset.theme.panel = CodableColor.random(darker: true, opacity: 0.72)
    preset.theme.pad = CodableColor.random(darker: true)
    preset.theme.scalePad = CodableColor.random(darker: true)
    preset.theme.activePad = CodableColor.random()
    preset.theme.padBorder = CodableColor(red: 1, green: 1, blue: 1, opacity: 0.9)
    preset.theme.padBorderWidth = Double.random(in: 3.0...5.0)
    preset.theme.padGlow = CodableColor.random(opacity: 0.45)
    preset.theme.activeGlow = CodableColor.random(opacity: 0.8)
    preset.theme.accent = CodableColor.random()
    preset.theme.markerColor = CodableColor.random(opacity: 0.75)
    preset.theme.gradientTop = CodableColor.random()
    preset.theme.gradientBottom = CodableColor.random()
    for index in preset.customLayout.items.indices {
      preset.customLayout.items[index].fill = CodableColor.random(darker: true)
      preset.customLayout.items[index].activeFill = CodableColor.random()
    }
  }

  private func press(note: Int, channel: Int, touchIntensity: Double? = nil) {
    let active = ActiveNote(note: note, channel: channel)
    if preset.sustainMode == .latch, activeNotes.contains(active) {
      forceRelease(active)
      return
    }

    if activeNotes.contains(active), heldSustainNotes.contains(active) == false {
      activeNoteCounts[active, default: 0] += 1
      return
    }
    activeNoteCounts[active, default: 0] += 1
    activeNotes.insert(active)
    let velocity = currentVelocity(touchIntensity: touchIntensity)
    lastSentVelocity = velocity
    activeNoteVelocities[active] = velocity
    midi.sendNoteOn(note: note, velocity: velocity, channel: channel, outputID: selectedOutputID)
    syncVibrato()
  }

  private func release(note: Int, channel: Int) {
    let active = ActiveNote(note: note, channel: channel)
    if let count = activeNoteCounts[active], count > 1 {
      activeNoteCounts[active] = count - 1
      return
    }
    activeNoteCounts.removeValue(forKey: active)
    switch preset.sustainMode {
    case .momentary:
      forceRelease(active)
    case .hold:
      if sustainButtonActive {
        heldSustainNotes.insert(active)
      } else {
        forceRelease(active)
      }
    case .latch:
      break
    }
  }

  private func forceRelease(_ active: ActiveNote) {
    activeNoteCounts.removeValue(forKey: active)
    guard activeNotes.remove(active) != nil else { return }
    activeNoteVelocities.removeValue(forKey: active)
    heldSustainNotes.remove(active)
    midi.sendNoteOff(note: active.note, channel: active.channel, outputID: selectedOutputID)
    midi.resetPitchBend(channel: active.channel, outputID: selectedOutputID)
    syncVibrato()
  }

  private func releaseSustainedNotes() {
    let notes = heldSustainNotes
    heldSustainNotes.removeAll()
    for note in notes {
      forceRelease(note)
    }
  }

  private func sendMotionValue(_ value: Int) {
    guard preset.motionToCC else { return }
    midi.sendControlChange(
      controller: preset.motionCC,
      value: value,
      channel: preset.midiChannel,
      outputID: selectedOutputID
    )
  }

  private func syncMotion() {
    if preset.motionToCC || preset.velocityMode == .accelerometer {
      motion.start()
    } else {
      motion.stop()
    }
  }

  private func currentVelocity(touchIntensity: Double? = nil) -> Int {
    let minVelocity = min(preset.velocityMin, preset.velocityMax)
    let maxVelocity = max(preset.velocityMin, preset.velocityMax)
    guard preset.velocityMode == .accelerometer else {
      return preset.velocity.clamped(to: 1...127)
    }
    guard let recentPeak = motion.recentPeak() else {
      return minVelocity.clamped(to: 1...127)
    }
    let adjusted = max(0, recentPeak - preset.accelFloor)
    let motionScaled = (adjusted / max(preset.accelMax, 0.01)) * preset.accelSensitivity
    let touchScaled = touchIntensity.map { max(0, min(1, $0)) * max(0, preset.touchForceSensitivity) } ?? 0
    let scaled = max(motionScaled, touchScaled)
    let normalized = max(0, min(1, scaled))
    let curved: Double
    switch preset.velocityCurve {
    case "linear":
      curved = normalized
    case "hard":
      curved = pow(normalized, 1.6)
    case "extreme":
      curved = pow(normalized, 2.3)
    default:
      curved = sqrt(normalized)
    }
    return Int((Double(minVelocity) + curved * Double(maxVelocity - minVelocity)).rounded()).clamped(to: 1...127)
  }

  private func sendKeyCommand(_ command: String) {
    lastKeyCommand = command
    // iPadOS does not expose a public API for synthesizing hardware keyboard events to other apps.
    // This records the command for in-app integrations and exported mappings.
  }

  private func syncVibrato() {
    if preset.vibratoEnabled && !activeNotes.isEmpty {
      startVibrato()
    } else {
      stopVibrato()
    }
  }

  private func startVibrato() {
    guard vibratoTimer == nil else { return }
    vibratoTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tickVibrato()
      }
    }
  }

  private func stopVibrato() {
    vibratoTimer?.invalidate()
    vibratoTimer = nil
    vibratoPhase = 0
    for channel in Set(activeNotes.map(\.channel)) {
      midi.resetPitchBend(channel: channel, outputID: selectedOutputID)
    }
  }

  private func tickVibrato() {
    guard preset.vibratoEnabled, !activeNotes.isEmpty else {
      stopVibrato()
      return
    }
    vibratoPhase += (1.0 / 60.0) * preset.vibratoRate * 2.0 * .pi
    let amount = sin(vibratoPhase) * preset.vibratoDepth
    for channel in Set(activeNotes.map(\.channel)) {
      midi.sendPitchBend(normalized: amount, channel: channel, outputID: selectedOutputID)
    }
  }

}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}

private extension CodableColor {
  static func random(darker: Bool = false, opacity: Double = 1) -> CodableColor {
    let lower = darker ? 0.02 : 0.25
    let upper = darker ? 0.35 : 1.0
    return CodableColor(
      red: Double.random(in: lower...upper),
      green: Double.random(in: lower...upper),
      blue: Double.random(in: lower...upper),
      opacity: opacity
    )
  }
}
