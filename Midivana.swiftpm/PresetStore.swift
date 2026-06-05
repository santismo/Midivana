import Foundation

struct MidivanaExport: Codable {
  var type: String
  var presets: [AppPreset]
  var layout: CustomLayout?
}

@MainActor
final class PresetStore: ObservableObject {
  @Published private(set) var presets: [AppPreset] = []

  private let fileName = "midivana-native-presets.json"

  init() {
    load()
  }

  func upsert(_ preset: AppPreset) {
    if let index = presets.firstIndex(where: { $0.id == preset.id }) {
      presets[index] = preset
    } else {
      presets.append(preset)
    }
    save()
  }

  func delete(_ preset: AppPreset) {
    presets.removeAll { $0.id == preset.id }
    if presets.isEmpty {
      presets = Self.factoryPresets
    }
    save()
  }

  func importData(_ data: Data) throws -> AppPreset {
    let decoder = JSONDecoder()
    if let export = try? decoder.decode(MidivanaExport.self, from: data), let first = export.presets.first {
      upsert(first)
      return first
    }
    let preset = try decoder.decode(AppPreset.self, from: data)
    upsert(preset)
    return preset
  }

  func exportData(for preset: AppPreset) throws -> Data {
    let payload = MidivanaExport(type: "midivana-native-preset", presets: [preset], layout: preset.customLayout)
    return try JSONEncoder.midivana.encode(payload)
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let decoded = try? JSONDecoder().decode([AppPreset].self, from: data) else {
      presets = Self.factoryPresets
      save()
      return
    }
    presets = decoded.isEmpty ? Self.factoryPresets : decoded
  }

  private func save() {
    do {
      let data = try JSONEncoder.midivana.encode(presets)
      try data.write(to: fileURL, options: [.atomic])
    } catch {
      print("Preset save failed: \(error)")
    }
  }

  private var fileURL: URL {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return directory.appendingPathComponent(fileName)
  }

  private static let factoryPresets: [AppPreset] = {
    var standard = AppPreset.default
    standard.name = "HTML Default"

    var drums = AppPreset.default
    drums.id = UUID()
    drums.name = "Drum Grid"
    drums.layout = .drums
    drums.midiChannel = 10
    drums.velocity = 118
    drums.scale = .chromatic
    drums.theme.pad = CodableColor(hex: 0x211C2A)
    drums.theme.activePad = CodableColor(hex: 0xFFB94C)

    var custom = AppPreset.default
    custom.id = UUID()
    custom.name = "Frets + Sliders"
    custom.layout = .custom
    custom.customLayout = .fretsAndSliders
    custom.cc1Visible = true
    custom.cc2Visible = true

    var gradient = AppPreset.default
    gradient.id = UUID()
    gradient.name = "Gradient Circles"
    gradient.theme.background = CodableColor(hex: 0x070A0B)
    gradient.theme.pad = CodableColor(hex: 0x162127)
    gradient.theme.scalePad = CodableColor(hex: 0x1A3732)
    gradient.theme.activePad = CodableColor(hex: 0x2AE6A1)
    gradient.theme.showNoteNames = true

    return [standard, gradient, drums, custom]
  }()
}

private extension JSONEncoder {
  static var midivana: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}
