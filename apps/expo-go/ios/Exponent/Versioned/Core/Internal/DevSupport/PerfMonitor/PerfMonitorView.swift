// Copyright 2025-present 650 Industries. All rights reserved.

import SwiftUI
import UIKit

struct PerfMonitorView: View {
  @ObservedObject var viewModel: PerfMonitorViewModel
  private let cardCornerRadius: CGFloat = 18
  private let graphHeight: CGFloat = 58
  private let maxCardWidth: CGFloat = 360
  private var cardWidth: CGFloat {
    min(UIScreen.main.bounds.width * 0.95, maxCardWidth)
  }
  private let cardBackground = Color(red: 0.11, green: 0.12, blue: 0.16)
  private let accentColor = Color(red: 0.27, green: 0.55, blue: 0.98)
  private let borderColor = Color.white.opacity(0.08)

  var body: some View {
    VStack(spacing: 12) {
      header

      VStack(spacing: 12) {
        fpsSection
        statsSection
      }
    }
    .padding(16)
    .frame(width: cardWidth)
    .background(cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        .stroke(borderColor, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.5), radius: 22, x: 0, y: 12)
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(Color.white.opacity(0.75))
        .frame(width: 28, height: 28)
      Spacer()
      Text("Performance monitor")
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundColor(.white.opacity(0.95))
      Spacer()
      Button(action: {
        viewModel.closeMonitor()
      }) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(Color.white.opacity(0.8))
          .font(.system(size: 20, weight: .semibold))
      }
      .buttonStyle(.plain)
    }
  }

  private var fpsSection: some View {
    HStack(spacing: 12) {
      PerfMonitorTrackView(
        snapshot: viewModel.snapshot.uiTrack,
        accentColor: accentColor,
        height: graphHeight
      )

      PerfMonitorTrackView(
        snapshot: viewModel.snapshot.jsTrack,
        accentColor: accentColor,
        height: graphHeight
      )
    }
  }

  private var statsSection: some View {
    HStack(spacing: 12) {
      PerfMonitorStatCard(
        title: "RAM",
        value: viewModel.snapshot.formattedMemory,
        unit: "MB",
      )
      PerfMonitorStatCard(
        title: "Hermes",
        value: viewModel.snapshot.formattedHeap,
        unit: "MB",
      )
      PerfMonitorStatCard(
        title: "Layout",
        value: viewModel.snapshot.formattedLayoutDuration,
        unit: "ms"
      )
    }
  }
}

private struct PerfMonitorTrackView: View {
  let snapshot: PerfMonitorTrackSnapshot
  let accentColor: Color
  let height: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      GraphView(values: snapshot.history, accentColor: accentColor)
        .frame(height: height)

      HStack {
        Text(snapshot.label.uppercased())
          .font(.caption)
          .foregroundColor(Color.white.opacity(0.65))
        Spacer()
        Text(snapshot.formattedFPS)
          .font(.system(size: 15, weight: .semibold, design: .rounded))
          .foregroundColor(.white)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.white.opacity(0.08))
    )
  }
}

private struct GraphView: View {
  let values: [Double]
  let accentColor: Color

  var body: some View {
    GeometryReader { proxy in
      let points = normalizedPoints(in: proxy.size)
      ZStack(alignment: .bottomLeading) {
        LinearGradient(
          gradient: Gradient(colors: [accentColor.opacity(0.5), accentColor.opacity(0.08)]),
          startPoint: .top,
          endPoint: .bottom
        )
        .mask(
          Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x, y: proxy.size.height))
            path.addLine(to: first)
            for point in points {
              path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: points.last?.x ?? proxy.size.width, y: proxy.size.height))
            path.closeSubpath()
          }
        )

        Path { path in
          guard let first = points.first else { return }
          path.move(to: first)
          for point in points.dropFirst() {
            path.addLine(to: point)
          }
        }
        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
      }
    }
  }

  private func normalizedPoints(in size: CGSize) -> [CGPoint] {
    guard !values.isEmpty else {
      return []
    }

    let minValue: Double = 0
    let maxValue: Double = 120
    let clampedValues = values.map { value in
      min(max(value, minValue), maxValue)
    }
    let range = max(maxValue - minValue, 1)

    let stepX = size.width / CGFloat(max(values.count - 1, 1))

    return clampedValues.enumerated().map { index, value in
      let normalized = (value - minValue) / range
      let y = size.height - CGFloat(normalized) * size.height
      let x = CGFloat(index) * stepX
      return CGPoint(x: x, y: y)
    }
  }
}

private struct PerfMonitorStatCard: View {
  var title: String
  var value: String
  var unit: String

  var body: some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundColor(Color.white.opacity(0.6))
      HStack(alignment: .firstTextBaseline) {
        Text(value)
          .font(.system(size: 18, weight: .semibold, design: .rounded))
          .foregroundColor(.white)
        if !unit.isEmpty {
          Text(unit)
            .font(.caption2)
            .foregroundColor(Color.white.opacity(0.6))
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 60)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.white.opacity(0.08))
    )
  }
}
