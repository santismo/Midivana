import Foundation

enum MidivanaResources {
  static func url(named resource: String, withExtension fileExtension: String) -> URL? {
    let primaryBundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
    let nestedBundles = primaryBundles.flatMap { bundle in
      (bundle.urls(forResourcesWithExtension: "bundle", subdirectory: nil) ?? []).compactMap(Bundle.init(url:))
    }
    return (primaryBundles + nestedBundles).lazy.compactMap {
      $0.url(forResource: resource, withExtension: fileExtension)
    }.first
  }
}

struct MidivanaExport: Codable {
  var type: String
  var presets: [AppPreset]
  var layout: CustomLayout?
}

private struct QuickLayoutMenu: Codable {
  var presetIDs: [UUID]
}

private enum PresetImportError: LocalizedError {
  case missingPreset
  case invalidPreset

  var errorDescription: String? {
    switch self {
    case .missingPreset:
      return "This Midivana export does not contain a preset."
    case .invalidPreset:
      return "This file is not a compatible Midivana preset."
    }
  }
}

@MainActor
final class PresetStore: ObservableObject {
  @Published private(set) var presets: [AppPreset] = []
  @Published private(set) var quickLayoutPresetIDs: [UUID] = []

  private let fileName = "midivana-native-presets.json"
  private let quickLayoutFileName = "midivana-quick-layouts.json"
  private static let bundledPresetMigrationKey = "MidivanaBundledPresetMigrationVersion"
  private static let bundledPresetMigrationVersion = 1

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
    quickLayoutPresetIDs.removeAll { $0 == preset.id }
    if presets.isEmpty {
      presets = Self.factoryPresets
    }
    save()
    saveQuickLayouts()
  }

  func importData(_ data: Data) throws -> AppPreset {
    let decoder = JSONDecoder()
    if let export = try? decoder.decode(MidivanaExport.self, from: data) {
      guard let first = export.presets.first else {
        throw PresetImportError.missingPreset
      }
      let imported = Self.preset(from: first, layout: export.layout)
      upsert(imported)
      return imported
    }
    do {
      let preset = try decoder.decode(AppPreset.self, from: data)
      upsert(preset)
      return preset
    } catch {
      throw PresetImportError.invalidPreset
    }
  }

  func exportData(for preset: AppPreset) throws -> Data {
    let payload = MidivanaExport(type: "midivana-native-preset", presets: [preset], layout: preset.customLayout)
    return try JSONEncoder.midivana.encode(payload)
  }

  var quickLayoutPresets: [AppPreset] {
    quickLayoutPresetIDs.compactMap { id in
      presets.first { $0.id == id }
    }
  }

  func isInQuickLayoutMenu(_ preset: AppPreset) -> Bool {
    quickLayoutPresetIDs.contains(preset.id)
  }

  func addToQuickLayoutMenu(_ preset: AppPreset) {
    upsert(preset)
    guard !quickLayoutPresetIDs.contains(preset.id) else { return }
    quickLayoutPresetIDs.append(preset.id)
    saveQuickLayouts()
  }

  func removeFromQuickLayoutMenu(_ preset: AppPreset) {
    quickLayoutPresetIDs.removeAll { $0 == preset.id }
    saveQuickLayouts()
  }

  func rename(_ presetID: UUID, to name: String) {
    guard let index = presets.firstIndex(where: { $0.id == presetID }) else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    presets[index].name = trimmed
    save()
  }

  private func load() {
    let decoded = (try? Data(contentsOf: fileURL)).flatMap { data in
      try? JSONDecoder().decode([AppPreset].self, from: data)
    }
    let needsBundledPresetMigration =
      UserDefaults.standard.integer(forKey: Self.bundledPresetMigrationKey) < Self.bundledPresetMigrationVersion
    let storedPresets = decoded?.isEmpty == false ? decoded! : Self.factoryPresets
    let migratedPresets = needsBundledPresetMigration
      ? Self.replacingBundledPresets(in: storedPresets)
      : storedPresets
    presets = mergedWithBundledPresets(migratedPresets)

    let savedQuickLayouts = (try? Data(contentsOf: quickLayoutFileURL)).flatMap { data in
      try? JSONDecoder().decode(QuickLayoutMenu.self, from: data)
    }
    let validIDs = Set(presets.map(\.id))
    let storedQuickLayoutIDs = (savedQuickLayouts?.presetIDs ?? Self.defaultQuickLayoutPresetIDs)
      .filter { validIDs.contains($0) }
    let defaultIDs = Self.defaultQuickLayoutPresetIDs.filter { validIDs.contains($0) }
    if needsBundledPresetMigration, !defaultIDs.isEmpty {
      let additionalIDs = storedQuickLayoutIDs.filter { !defaultIDs.contains($0) }
      quickLayoutPresetIDs = defaultIDs + additionalIDs
      UserDefaults.standard.set(Self.bundledPresetMigrationVersion, forKey: Self.bundledPresetMigrationKey)
    } else {
      quickLayoutPresetIDs = storedQuickLayoutIDs
    }
    if quickLayoutPresetIDs.isEmpty {
      quickLayoutPresetIDs = Self.defaultQuickLayoutPresetIDs.filter { validIDs.contains($0) }
    }
    save()
    saveQuickLayouts()
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

  private var quickLayoutFileURL: URL {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return directory.appendingPathComponent(quickLayoutFileName)
  }

  private func saveQuickLayouts() {
    do {
      let data = try JSONEncoder.midivana.encode(QuickLayoutMenu(presetIDs: quickLayoutPresetIDs))
      try data.write(to: quickLayoutFileURL, options: [.atomic])
    } catch {
      print("Quick layout save failed: \(error)")
    }
  }

  private static func preset(from preset: AppPreset, layout: CustomLayout?) -> AppPreset {
    var imported = preset
    if imported.layout == .custom, let layout, !layout.items.isEmpty {
      imported.customLayout = layout
    }
    return imported
  }

  private func mergedWithBundledPresets(_ existing: [AppPreset]) -> [AppPreset] {
    let bundled = Self.bundledPresets
    var merged = existing
    for preset in bundled where !merged.contains(where: { $0.id == preset.id }) {
      merged.append(preset)
    }
    let bundledOrder = Dictionary(uniqueKeysWithValues: bundled.enumerated().map { ($0.element.id, $0.offset) })
    return merged.enumerated().sorted { lhs, rhs in
      let lhsOrder = bundledOrder[lhs.element.id] ?? .max
      let rhsOrder = bundledOrder[rhs.element.id] ?? .max
      return lhsOrder == rhsOrder ? lhs.offset < rhs.offset : lhsOrder < rhsOrder
    }.map(\.element)
  }

  private static var factoryPresets: [AppPreset] {
    bundledPresets + fallbackPresets
  }

  private static var defaultQuickLayoutPresetIDs: [UUID] {
    bundledPresets.map(\.id)
  }

  private static func replacingBundledPresets(in existing: [AppPreset]) -> [AppPreset] {
    let bundled = bundledPresets
    let bundledIDs = Set(bundled.map(\.id))
    return existing.filter { !bundledIDs.contains($0.id) } + bundled
  }

  private static var bundledPresets: [AppPreset] {
    [
      bundledPreset(resource: "Darkness Octo", displayName: "Darkness Octo"),
      bundledPreset(resource: "XO -", displayName: "XO"),
      bundledPreset(resource: "Drum Grid Custom Cc Boss", displayName: "Drum Grid Custom CC Boss")
    ]
    .compactMap { $0 }
  }

  private static func bundledPreset(resource: String, displayName: String) -> AppPreset? {
    guard let url = bundledResourceURL(named: resource),
          let data = try? Data(contentsOf: url),
          let export = try? JSONDecoder().decode(MidivanaExport.self, from: data),
          let first = export.presets.first else {
      return nil
    }
    var preset = preset(from: first, layout: export.layout)
    preset.name = displayName
    return preset
  }

  private static func bundledResourceURL(named resource: String) -> URL? {
    MidivanaResources.url(named: resource, withExtension: "json")
  }

  private static let fallbackPresets: [AppPreset] = {
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
