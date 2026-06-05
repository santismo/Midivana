import SwiftUI
import WebKit
import CoreMIDI
import CoreMotion
import UIKit

struct WebView: UIViewRepresentable {
  let html: String
  let baseURL: URL?

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let contentController = WKUserContentController()
    contentController.add(context.coordinator, name: "midi")
    contentController.add(context.coordinator, name: "motion")
    contentController.add(context.coordinator, name: "storage")
    let motionScript = """
    window.NativeMotionBridge = window.NativeMotionBridge || {};
    window.NativeMotionBridge._update = function(_) {};
    window.NativeMotionBridge.start = function() {
      window.webkit.messageHandlers.motion.postMessage({ type: "start" });
    };
    window.NativeMotionBridge.stop = function() {
      window.webkit.messageHandlers.motion.postMessage({ type: "stop" });
    };
    """
    contentController.addUserScript(WKUserScript(source: motionScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))

    let config = WKWebViewConfiguration()
    config.userContentController = contentController
    config.allowsInlineMediaPlayback = true
    if #available(iOS 16.4, *) {
      config.defaultWebpagePreferences.allowsContentJavaScript = true
    }

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.isOpaque = false
    webView.backgroundColor = .black
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.allowsLinkPreview = false
    context.coordinator.webView = webView
    context.coordinator.startMidiInput()

    webView.loadHTMLString(html, baseURL: baseURL)
    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class MidiManager {
  private var client = MIDIClientRef()
  private var outputPort = MIDIPortRef()
  private var inputPort = MIDIPortRef()
  private var ready = false
  private var connectedSources = Set<Int32>()
  private var inputHandler: (([UInt8]) -> Void)?

  init() {
    let clientStatus = MIDIClientCreate("Midivana" as CFString, nil, nil, &client)
    if clientStatus != noErr { return }
    let portStatus = MIDIOutputPortCreate(client, "Midivana Output" as CFString, &outputPort)
    ready = portStatus == noErr
  }

  func outputs() -> [(id: Int32, name: String, endpoint: MIDIEndpointRef)] {
    guard ready else { return [] }
    let count = MIDIGetNumberOfDestinations()
    guard count > 0 else { return [] }
    var results: [(Int32, String, MIDIEndpointRef)] = []
    for index in 0..<count {
      let endpoint = MIDIGetDestination(index)
      var uniqueID: Int32 = 0
      _ = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
      var nameRef: Unmanaged<CFString>?
      _ = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &nameRef)
      let name = (nameRef?.takeRetainedValue() as String?) ?? "Output \(index + 1)"
      results.append((uniqueID, name, endpoint))
    }
    return results
  }

  func inputs() -> [(id: Int32, name: String, endpoint: MIDIEndpointRef)] {
    guard ready else { return [] }
    let count = MIDIGetNumberOfSources()
    guard count > 0 else { return [] }
    var results: [(Int32, String, MIDIEndpointRef)] = []
    for index in 0..<count {
      let endpoint = MIDIGetSource(index)
      var uniqueID: Int32 = 0
      _ = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
      var nameRef: Unmanaged<CFString>?
      _ = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &nameRef)
      let name = (nameRef?.takeRetainedValue() as String?) ?? "Input \(index + 1)"
      results.append((uniqueID, name, endpoint))
    }
    return results
  }

  func endpoint(for outputId: Int32) -> MIDIEndpointRef? {
    let list = outputs()
    return list.first(where: { $0.id == outputId })?.endpoint
  }

  func send(data: [UInt8], to outputId: Int32) {
    guard ready, let endpoint = endpoint(for: outputId), !data.isEmpty else { return }
    var packetList = MIDIPacketList()
    let capacity = 1024
    data.withUnsafeBufferPointer { buffer in
      let packet = MIDIPacketListInit(&packetList)
      _ = MIDIPacketListAdd(&packetList, capacity, packet, 0, buffer.count, buffer.baseAddress!)
    }
    MIDISend(outputPort, endpoint, &packetList)
  }

  func startInput(handler: @escaping ([UInt8]) -> Void) {
    inputHandler = handler
    guard ready else { return }
    if inputPort == 0 {
      MIDIInputPortCreateWithBlock(client, "Midivana Input" as CFString, &inputPort) { [weak self] packetList, _ in
        self?.handleIncomingPackets(packetList)
      }
    }
    connectSources()
  }

  private func connectSources() {
    let count = MIDIGetNumberOfSources()
    guard count > 0 else { return }
    for index in 0..<count {
      let source = MIDIGetSource(index)
      guard source != 0 else { continue }
      let id = Int32(source)
      if connectedSources.contains(id) { continue }
      MIDIPortConnectSource(inputPort, source, nil)
      connectedSources.insert(id)
    }
  }

  private func handleIncomingPackets(_ packetList: UnsafePointer<MIDIPacketList>) {
    var packet = packetList.pointee.packet
    for _ in 0..<packetList.pointee.numPackets {
      let length = Int(packet.length)
      if length > 0 {
        let bytes = withUnsafeBytes(of: packet.data) { buffer -> [UInt8] in
          Array(buffer.prefix(length))
        }
        inputHandler?(bytes)
      }
      packet = MIDIPacketNext(&packet).pointee
    }
  }
}

final class Coordinator: NSObject, WKScriptMessageHandler {
  weak var webView: WKWebView?
  private let midiManager = MidiManager()
  private let motionManager = CMMotionManager()
  private var motionLink: CADisplayLink?
  private var motionActive = false

  func startMidiInput() {
    midiManager.startInput { [weak self] bytes in
      self?.deliverInput(bytes)
    }
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
    switch message.name {
    case "midi":
      switch type {
      case "request":
        deliverOutputs()
      case "requestInputs":
        deliverInputs()
      case "send":
        guard let outputId = parseOutputId(body["outputId"]) else { return }
        let data = parseBytes(body["data"])
        midiManager.send(data: data, to: outputId)
      default:
        break
      }
    case "motion":
      if type == "start" {
        startMotion()
      } else if type == "stop" {
        stopMotion()
      }
    case "storage":
      let name = body["name"] as? String ?? ""
      let requestId = (body["requestId"] as? String) ?? (body["requestId"] as? NSNumber)?.stringValue
      if type == "save" {
        guard !name.isEmpty, let data = body["data"] as? String else { return }
        saveStorageFile(name: name, data: data)
      } else if type == "load" {
        guard !name.isEmpty else { return }
        let data = loadStorageFile(name: name)
        deliverStorage(name: name, data: data, requestId: requestId)
      }
    default:
      break
    }
  }

  private func deliverOutputs() {
    let outputs = midiManager.outputs().map { ["id": $0.id, "name": $0.name] }
    guard let data = try? JSONSerialization.data(withJSONObject: outputs),
          let json = String(data: data, encoding: .utf8) else { return }
    let script = "window.NativeMidiBridge && window.NativeMidiBridge._deliver(\(json));"
    DispatchQueue.main.async { [weak self] in
      self?.webView?.evaluateJavaScript(script, completionHandler: nil)
    }
  }

  private func deliverInputs() {
    let inputs = midiManager.inputs().map { ["id": $0.id, "name": $0.name] }
    guard let data = try? JSONSerialization.data(withJSONObject: inputs),
          let json = String(data: data, encoding: .utf8) else { return }
    let script = "window.NativeMidiBridge && window.NativeMidiBridge._deliverInputs(\(json));"
    DispatchQueue.main.async { [weak self] in
      self?.webView?.evaluateJavaScript(script, completionHandler: nil)
    }
  }

  private func deliverInput(_ bytes: [UInt8]) {
    guard !bytes.isEmpty else { return }
    let payload = bytes.map { Int($0) }
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return }
    let script = "window.NativeMidiBridge && window.NativeMidiBridge._receive({data:\(json)});"
    DispatchQueue.main.async { [weak self] in
      self?.webView?.evaluateJavaScript(script, completionHandler: nil)
    }
  }

  private func storageDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  private func storageURL(for name: String) -> URL {
    storageDirectory().appendingPathComponent(name)
  }

  private func saveStorageFile(name: String, data: String) {
    let url = storageURL(for: name)
    do {
      try data.write(to: url, atomically: true, encoding: .utf8)
    } catch {
      print("Storage save failed: \(error)")
    }
  }

  private func loadStorageFile(name: String) -> String? {
    let url = storageURL(for: name)
    return try? String(contentsOf: url, encoding: .utf8)
  }

  private func deliverStorage(name: String, data: String?, requestId: String?) {
    var payload: [String: Any] = [
      "name": name,
      "data": data ?? NSNull()
    ]
    if let requestId = requestId {
      payload["requestId"] = requestId
    }
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: jsonData, encoding: .utf8) else { return }
    let script = "window.NativeStorageBridge && window.NativeStorageBridge._deliver(\(json));"
    DispatchQueue.main.async { [weak self] in
      self?.webView?.evaluateJavaScript(script, completionHandler: nil)
    }
  }

  private func parseOutputId(_ value: Any?) -> Int32? {
    if let number = value as? NSNumber {
      return number.int32Value
    }
    if let string = value as? String {
      return Int32(string)
    }
    return nil
  }

  private func parseBytes(_ value: Any?) -> [UInt8] {
    guard let list = value as? [Any] else { return [] }
    return list.compactMap { item in
      if let number = item as? NSNumber { return UInt8(truncating: number) }
      if let intVal = item as? Int { return UInt8(clamping: intVal) }
      return nil
    }
  }

  private func startMotion() {
    guard !motionActive else { return }
    if motionManager.isDeviceMotionAvailable {
      let fps = Double(UIScreen.main.maximumFramesPerSecond)
      motionManager.deviceMotionUpdateInterval = 1.0 / fps
      motionManager.startDeviceMotionUpdates()
    } else if motionManager.isAccelerometerAvailable {
      let fps = Double(UIScreen.main.maximumFramesPerSecond)
      motionManager.accelerometerUpdateInterval = 1.0 / fps
      motionManager.startAccelerometerUpdates()
    } else {
      return
    }
    motionActive = true
    startMotionLink()
  }

  private func stopMotion() {
    guard motionActive else { return }
    motionActive = false
    motionLink?.invalidate()
    motionLink = nil
    motionManager.stopDeviceMotionUpdates()
    motionManager.stopAccelerometerUpdates()
  }

  private func startMotionLink() {
    motionLink?.invalidate()
    let link = CADisplayLink(target: self, selector: #selector(handleMotionTick))
    link.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
    link.add(to: .main, forMode: .common)
    motionLink = link
  }

  @objc private func handleMotionTick() {
    guard motionActive else { return }
    var ax = 0.0
    var ay = 0.0
    var az = 0.0
    var linear = true
    if let data = motionManager.deviceMotion {
      let accel = data.userAcceleration
      ax = accel.x
      ay = accel.y
      az = accel.z
      linear = true
    } else if let data = motionManager.accelerometerData {
      let accel = data.acceleration
      ax = accel.x
      ay = accel.y
      az = accel.z
      linear = false
    } else {
      return
    }
    sendMotionSample(ax: ax, ay: ay, az: az, linear: linear)
  }

  private func sendMotionSample(ax: Double, ay: Double, az: Double, linear: Bool) {
    let payload = String(format: "{\"x\":%.5f,\"y\":%.5f,\"z\":%.5f,\"linear\":%@}", ax, ay, az, linear ? "true" : "false")
    let script = "window.NativeMotionBridge && window.NativeMotionBridge._update(\(payload));"
    DispatchQueue.main.async { [weak self] in
      self?.webView?.evaluateJavaScript(script, completionHandler: nil)
    }
  }
}
