import Combine
import CoreMIDI
import Foundation

final class MIDIService: ObservableObject {
  @Published private(set) var outputs: [MIDIEndpointInfo] = []
  @Published private(set) var inputs: [MIDIEndpointInfo] = []
  @Published private(set) var lastIncomingMessage: [UInt8] = []
  @Published private(set) var externalActiveNotes = Set<ActiveNote>()

  private var client = MIDIClientRef()
  private var outputPort = MIDIPortRef()
  private var inputPort = MIDIPortRef()
  private var destinationsByID: [Int32: MIDIEndpointRef] = [:]
  private var sourcesByID: [Int32: MIDIEndpointRef] = [:]
  private var connectedSourceIDs = Set<Int32>()
  private var selectedInputID: Int32?
  private var isReady = false
  private let sendQueue = DispatchQueue(label: "Midivana.MIDI.Send", qos: .userInitiated)

  init() {
    let clientStatus = MIDIClientCreate("Midivana" as CFString, nil, nil, &client)
    guard clientStatus == noErr else { return }

    let outputStatus = MIDIOutputPortCreate(client, "Midivana Output" as CFString, &outputPort)
    guard outputStatus == noErr else { return }

    let inputStatus = MIDIInputPortCreateWithBlock(client, "Midivana Input" as CFString, &inputPort) { [weak self] packetList, _ in
      self?.handleIncomingPackets(packetList)
    }

    isReady = inputStatus == noErr
    refreshEndpoints()
  }

  func refreshEndpoints() {
    guard isReady else { return }

    var nextDestinations: [Int32: MIDIEndpointRef] = [:]
    var nextOutputs: [MIDIEndpointInfo] = []
    for index in 0..<MIDIGetNumberOfDestinations() {
      let endpoint = MIDIGetDestination(index)
      let id = uniqueID(for: endpoint, fallback: Int32(index + 1))
      nextDestinations[id] = endpoint
      nextOutputs.append(MIDIEndpointInfo(id: id, name: endpointName(endpoint, fallback: "Output \(index + 1)")))
    }

    var nextSources: [Int32: MIDIEndpointRef] = [:]
    var nextInputs: [MIDIEndpointInfo] = []
    for index in 0..<MIDIGetNumberOfSources() {
      let endpoint = MIDIGetSource(index)
      let id = uniqueID(for: endpoint, fallback: Int32(index + 1))
      nextSources[id] = endpoint
      nextInputs.append(MIDIEndpointInfo(id: id, name: endpointName(endpoint, fallback: "Input \(index + 1)")))
    }

    destinationsByID = nextDestinations
    sourcesByID = nextSources
    reconnectInputSources()

    DispatchQueue.main.async {
      self.outputs = nextOutputs
      self.inputs = nextInputs
    }
  }

  func sendNoteOn(note: Int, velocity: Int, channel: Int, outputID: Int32?) {
    send(status: 0x90, data1: note, data2: velocity, channel: channel, outputID: outputID)
  }

  func sendNoteOff(note: Int, channel: Int, outputID: Int32?) {
    send(status: 0x80, data1: note, data2: 0, channel: channel, outputID: outputID)
  }

  func sendControlChange(controller: Int, value: Int, channel: Int, outputID: Int32?) {
    send(status: 0xB0, data1: controller, data2: value, channel: channel, outputID: outputID)
  }

  func sendPitchBend(normalized: Double, channel: Int, outputID: Int32?) {
    let clamped = max(-1, min(1, normalized))
    let value = Int((8192 + clamped * 8191).rounded()).clamped(to: 0...16383)
    let lsb = value & 0x7F
    let msb = (value >> 7) & 0x7F
    send(status: 0xE0, data1: lsb, data2: msb, channel: channel, outputID: outputID)
  }

  func resetPitchBend(channel: Int, outputID: Int32?) {
    sendPitchBend(normalized: 0, channel: channel, outputID: outputID)
  }

  func sendAllNotesOff(channel: Int, outputID: Int32?) {
    sendControlChange(controller: 123, value: 0, channel: channel, outputID: outputID)
    sendControlChange(controller: 120, value: 0, channel: channel, outputID: outputID)
    resetPitchBend(channel: channel, outputID: outputID)
  }

  func selectInput(_ inputID: Int32?) {
    selectedInputID = inputID
    reconnectInputSources()
  }

  private func send(status: UInt8, data1: Int, data2: Int, channel: Int, outputID: Int32?) {
    guard isReady, let destination = destination(for: outputID) else { return }
    let channelNibble = UInt8(max(0, min(15, channel - 1)))
    let bytes = [status | channelNibble, UInt8(clamping: data1), UInt8(clamping: data2)]
    send(bytes, to: destination)
  }

  private func destination(for outputID: Int32?) -> MIDIEndpointRef? {
    if let outputID, let destination = destinationsByID[outputID] {
      return destination
    }
    return destinationsByID.values.first
  }

  private func send(_ bytes: [UInt8], to destination: MIDIEndpointRef) {
    guard !bytes.isEmpty, outputPort != 0 else { return }
    let outputPort = outputPort

    sendQueue.async {
      var packetList = MIDIPacketList()
      let packetWasAdded = bytes.withUnsafeBufferPointer { buffer -> Bool in
        guard let baseAddress = buffer.baseAddress else { return false }
        let packet = MIDIPacketListInit(&packetList)
        _ = MIDIPacketListAdd(&packetList, 1024, packet, 0, buffer.count, baseAddress)
        return true
      }
      guard packetWasAdded else { return }
      MIDISend(outputPort, destination, &packetList)
    }
  }

  private func connectInputSources() {
    guard inputPort != 0 else { return }
    for (id, source) in sourcesByID where !connectedSourceIDs.contains(id) {
      if let selectedInputID, selectedInputID != id { continue }
      MIDIPortConnectSource(inputPort, source, nil)
      connectedSourceIDs.insert(id)
    }
  }

  private func reconnectInputSources() {
    guard inputPort != 0 else { return }
    for id in connectedSourceIDs {
      if let source = sourcesByID[id] {
        MIDIPortDisconnectSource(inputPort, source)
      }
    }
    connectedSourceIDs.removeAll()
    connectInputSources()
  }

  private func handleIncomingPackets(_ packetList: UnsafePointer<MIDIPacketList>) {
    var packet = packetList.pointee.packet
    for _ in 0..<packetList.pointee.numPackets {
      let length = Int(packet.length)
      if length > 0 {
        let bytes = withUnsafeBytes(of: packet.data) { buffer in
          Array(buffer.prefix(length))
        }
        DispatchQueue.main.async {
          self.lastIncomingMessage = bytes
          self.applyIncoming(bytes)
        }
      }
      packet = MIDIPacketNext(&packet).pointee
    }
  }

  private func applyIncoming(_ bytes: [UInt8]) {
    guard bytes.count >= 3 else { return }
    let status = bytes[0] & 0xF0
    let channel = Int(bytes[0] & 0x0F) + 1
    let note = Int(bytes[1])
    let velocity = Int(bytes[2])
    let active = ActiveNote(note: note, channel: channel)

    if status == 0x90 && velocity > 0 {
      externalActiveNotes.insert(active)
    } else if status == 0x80 || (status == 0x90 && velocity == 0) {
      externalActiveNotes.remove(active)
    }
  }

  private func uniqueID(for endpoint: MIDIEndpointRef, fallback: Int32) -> Int32 {
    var uniqueID = fallback
    _ = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
    return uniqueID
  }

  private func endpointName(_ endpoint: MIDIEndpointRef, fallback: String) -> String {
    var nameRef: Unmanaged<CFString>?
    _ = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &nameRef)
    return (nameRef?.takeRetainedValue() as String?) ?? fallback
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
