import CoreMotion
import Foundation
import UIKit

final class MotionService: NSObject, ObservableObject {
  @Published private(set) var normalizedValue = 64
  @Published private(set) var acceleration = 0.0
  @Published private(set) var motionLevel = 0.0

  var valueHandler: ((Int) -> Void)?

  private let motionManager = CMMotionManager()
  private var displayLink: CADisplayLink?
  private var isRunning = false
  private var baseline = 0.0
  private var previousMagnitude = 0.0
  private var peak = 0.0
  private var peakAt = Date.distantPast
  private var lastSampleAt = Date.distantPast

  func start() {
    guard !isRunning else { return }

    let fps = Double(max(30, UIScreen.main.maximumFramesPerSecond))
    if motionManager.isDeviceMotionAvailable {
      motionManager.deviceMotionUpdateInterval = 1.0 / fps
      motionManager.startDeviceMotionUpdates()
    } else if motionManager.isAccelerometerAvailable {
      motionManager.accelerometerUpdateInterval = 1.0 / fps
      motionManager.startAccelerometerUpdates()
    } else {
      return
    }

    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.preferredFramesPerSecond = Int(fps)
    link.add(to: .main, forMode: .common)
    displayLink = link
    isRunning = true
  }

  func stop() {
    guard isRunning else { return }
    isRunning = false
    displayLink?.invalidate()
    displayLink = nil
    motionManager.stopDeviceMotionUpdates()
    motionManager.stopAccelerometerUpdates()
  }

  @objc private func tick() {
    let x: Double
    let accelerationSample: Double
    let hasLinear: Bool
    if let motion = motionManager.deviceMotion {
      x = motion.attitude.roll
      let user = motion.userAcceleration
      accelerationSample = sqrt(user.x * user.x + user.y * user.y + user.z * user.z)
      hasLinear = true
    } else if let accelerometer = motionManager.accelerometerData {
      x = accelerometer.acceleration.x
      let value = accelerometer.acceleration
      accelerationSample = sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
      hasLinear = false
    } else {
      return
    }

    acceleration = accelerationSample
    updatePeak(magnitude: accelerationSample, hasLinear: hasLinear)
    let value = Int(((x + 1.0) / 2.0 * 127.0).rounded()).clamped(to: 0...127)
    guard value != normalizedValue else { return }
    normalizedValue = value
    valueHandler?(value)
  }

  func recentPeak(maxAge: TimeInterval = 0.18) -> Double? {
    let now = Date()
    guard now.timeIntervalSince(lastSampleAt) <= maxAge else { return nil }
    if now.timeIntervalSince(peakAt) <= maxAge {
      return peak
    }
    return motionLevel
  }

  private func updatePeak(magnitude: Double, hasLinear: Bool) {
    let now = Date()
    let deltaTime = max(0.001, now.timeIntervalSince(lastSampleAt))
    let jerk = abs(magnitude - previousMagnitude) / deltaTime
    previousMagnitude = magnitude

    if !hasLinear {
      baseline = baseline * 0.8 + magnitude * 0.2
    }

    let delta = max(0, hasLinear ? magnitude : magnitude - baseline)
    let impulse = max(delta, jerk * 0.04)
    motionLevel = motionLevel * 0.4 + impulse * 0.6
    if impulse > peak || now.timeIntervalSince(peakAt) > 0.12 {
      peak = impulse
      peakAt = now
    }
    lastSampleAt = now
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
