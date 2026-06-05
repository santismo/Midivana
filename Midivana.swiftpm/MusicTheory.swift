import Foundation

enum MusicTheory {
  static let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
  static let guitarTuningHighToLow = [64, 59, 55, 50, 45, 40]
  static let defaultDrumNotes = [
    36, 38, 42, 46,
    41, 43, 45, 47,
    48, 50, 49, 51,
    55, 57, 39, 37
  ]
  static let drumNames = [
    "Kick", "Snare", "Hat", "Open",
    "Tom 1", "Tom 2", "Tom 3", "Tom 4",
    "Tom 5", "Tom 6", "Crash", "Ride",
    "Splash", "Crash 2", "Clap", "Rim"
  ]

  static func noteName(_ midiNote: Int) -> String {
    let pitch = ((midiNote % 12) + 12) % 12
    let octave = midiNote / 12 - 1
    return "\(noteNames[pitch])\(octave)"
  }

  static func pitchName(_ pitch: Int) -> String {
    noteNames[((pitch % 12) + 12) % 12]
  }

  static func isInScale(note: Int, root: Int, scale: ScaleKind) -> Bool {
    let relative = ((note - root) % 12 + 12) % 12
    return scale.intervals.contains(relative)
  }

  static func fretboardPads(for preset: AppPreset) -> [[NotePad]] {
    let octaveOffset = (preset.baseOctave - 4) * 12
    return preset.stringTunings.enumerated().map { row, openNote in
      let channel = preset.stringChannels.indices.contains(row) ? preset.stringChannels[row] : preset.midiChannel
      return (0..<preset.fretCount).map { fret in
        let note = openNote + octaveOffset + fret
        return NotePad(
          id: "fret-\(row)-\(fret)",
          note: note,
          title: noteName(note),
          subtitle: fret == 0 ? "0" : "\(fret)",
          row: row,
          column: fret,
          channel: channel,
          isInScale: isInScale(note: note, root: preset.rootNote, scale: preset.scale)
        )
      }
    }
  }

  static func keyboardPads(for preset: AppPreset) -> [[NotePad]] {
    let totalNotes = max(12, min(48, preset.keyboardOctaves * 12))
    let notesPerRow = max(1, totalNotes / max(1, preset.keyboardRows))
    let start = 12 * (preset.baseOctave + 1) + preset.rootNote
    let notes = (0..<totalNotes).map { start + $0 }
    return stride(from: 0, to: notes.count, by: notesPerRow).map { rowStart in
      notes[rowStart..<min(rowStart + notesPerRow, notes.count)].enumerated().map { offset, note in
        NotePad(
          id: "key-\(rowStart + offset)",
          note: note,
          title: pitchName(note),
          subtitle: noteName(note),
          row: rowStart / notesPerRow,
          column: offset,
          channel: preset.midiChannel,
          isInScale: isInScale(note: note, root: preset.rootNote, scale: preset.scale)
        )
      }
    }
  }

  static func drumPads(for preset: AppPreset) -> [[NotePad]] {
    let columns = max(1, preset.drumColumns)
    return stride(from: 0, to: preset.drumMap.count, by: columns).map { rowStart in
      preset.drumMap[rowStart..<min(rowStart + columns, preset.drumMap.count)].enumerated().map { offset, note in
        let index = rowStart + offset
        return NotePad(
          id: "drum-\(index)",
          note: note,
          title: index < drumNames.count ? drumNames[index] : "Pad \(index + 1)",
          subtitle: noteName(note),
          row: rowStart / columns,
          column: offset,
          channel: 10,
          isInScale: true
        )
      }
    }
  }
}
