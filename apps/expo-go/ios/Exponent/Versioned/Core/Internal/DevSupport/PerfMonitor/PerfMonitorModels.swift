// Copyright 2025-present 650 Industries. All rights reserved.

import Foundation
import SwiftUI
import UIKit

@objc enum PerfMonitorTrack: Int {
  case ui = 0
  case js = 1

  var displayName: String {
    switch self {
    case .ui:
      return "UI"
    case .js:
      return "JS"
    }
  }
}

struct PerfMonitorSnapshot: Equatable {
  var uiTrack: PerfMonitorTrackSnapshot
  var jsTrack: PerfMonitorTrackSnapshot
  var memoryMB: Double
  var heapMB: Double
  var layoutDurationMS: Double

  var formattedMemory: String {
    String(format: "%.2f", memoryMB)
  }

  var formattedHeap: String {
    String(format: "%.2f", heapMB)
  }

  var formattedLayoutDuration: String {
    String(format: "%.1f", layoutDurationMS)
  }
}

struct PerfMonitorTrackSnapshot: Equatable {
  var label: String
  var currentFPS: Int
  var history: [Double]

  var formattedFPS: String {
    "\(currentFPS) fps"
  }
}


@objcMembers
@MainActor
final class PerfMonitorViewModel: NSObject, ObservableObject {
  @Published private(set) var snapshot: PerfMonitorSnapshot
  private var closeHandler: (() -> Void)?

  override init() {
    self.snapshot = PerfMonitorSnapshot(
      uiTrack: PerfMonitorTrackSnapshot(label: PerfMonitorTrack.ui.displayName, currentFPS: 0, history: []),
      jsTrack: PerfMonitorTrackSnapshot(label: PerfMonitorTrack.js.displayName, currentFPS: 0, history: []),
      memoryMB: 0,
      heapMB: 0,
      layoutDurationMS: 0
    )
    super.init()
  }

  init(snapshot: PerfMonitorSnapshot) {
    self.snapshot = snapshot
    super.init()
  }

  func update(snapshot: PerfMonitorSnapshot) {
    self.snapshot = snapshot
  }

  func updateStats(memoryMB: NSNumber, heapMB: NSNumber, layoutDurationMS: NSNumber) {
    updateSnapshot {
      $0.memoryMB = memoryMB.doubleValue
      $0.heapMB = heapMB.doubleValue
      $0.layoutDurationMS = layoutDurationMS.doubleValue
    }
  }

  func updateTrack(_ track: PerfMonitorTrack, currentFPS: NSNumber, history: [NSNumber]) {
    let fpsValue = currentFPS.intValue
    let historyValues = history.map { $0.doubleValue }

    updateSnapshot { snapshot in
      let trackSnapshot = PerfMonitorTrackSnapshot(
        label: track.displayName,
        currentFPS: fpsValue,
        history: historyValues
      )

      switch track {
      case .ui:
        snapshot.uiTrack = trackSnapshot
      case .js:
        snapshot.jsTrack = trackSnapshot
      }
    }
  }

  func setCloseHandler(_ handler: @escaping () -> Void) {
    closeHandler = handler
  }

  func closeMonitor() {
    closeHandler?()
  }

  func clearCloseHandler() {
    closeHandler = nil
  }

  private func updateSnapshot(_ transform: (inout PerfMonitorSnapshot) -> Void) {
    var copy = snapshot
    transform(&copy)
    snapshot = copy
  }
}

@objc(EXPerfMonitorPresenter)
@objcMembers
@MainActor
final class PerfMonitorPresenter: NSObject {
  let viewModel: PerfMonitorViewModel
  private let hostingController: PerfMonitorHostingController

  override init() {
    self.viewModel = PerfMonitorViewModel()
    self.hostingController = PerfMonitorHostingController(viewModel: self.viewModel)
    super.init()
  }

  var view: UIView {
    hostingController.view
  }

  func setContentSizeHandler(_ handler: @escaping (NSValue) -> Void) {
    hostingController.contentSizeDidChange = handler
  }

  func clearContentSizeHandler() {
    hostingController.contentSizeDidChange = nil
    viewModel.clearCloseHandler()
  }

  func currentContentSizeValue() -> NSValue {
    let preferredSize = hostingController.preferredContentSize
    if preferredSize != .zero {
      return NSValue(cgSize: preferredSize)
    }
    let intrinsic = hostingController.view.intrinsicContentSize
    let maxWidth: CGFloat = 360
    let targetWidth = min(UIScreen.main.bounds.width * 0.95, maxWidth)
    let fallbackHeight: CGFloat = 176
    let fallback = CGSize(width: targetWidth, height: fallbackHeight)
    return NSValue(cgSize: intrinsic == .zero ? fallback : intrinsic)
  }

  @objc
  func updateStats(memoryMB: NSNumber, heapMB: NSNumber, layoutDurationMS: NSNumber) {
    viewModel.updateStats(memoryMB: memoryMB, heapMB: heapMB, layoutDurationMS: layoutDurationMS)
  }

  func updateTrack(_ track: PerfMonitorTrack, currentFPS: NSNumber, history: [NSNumber]) {
    viewModel.updateTrack(track, currentFPS: currentFPS, history: history)
  }

  func setCloseHandler(_ handler: @escaping () -> Void) {
    viewModel.setCloseHandler(handler)
  }
}
