//
//  LineByLine.swift
//  InferX
//
//  Created by mingdw on 2025/5/28.
//

import SwiftUI

struct LineByLineEffect: TextRenderer {
  var elapsedTime: TimeInterval // Time elapsed since the start of the animation
  var elementDuration: TimeInterval // Duration of each element's animation
  var totalDuration: TimeInterval // Total duration of the animation

  var animatableData: Double {
    get { elapsedTime } // Get the elapsed time
    set {
      elapsedTime = newValue // Set the elapsed time
    }
  }

  init(elapsedTime: TimeInterval, elementDuration: Double = 0.5, totalDuration: TimeInterval) {
    // Initialize with elapsed time, element duration, and total duration
    self.elapsedTime = min(elapsedTime, totalDuration) // Ensure elapsed time does not exceed total duration
    self.elementDuration = min(elementDuration, totalDuration) // Ensure element duration does not exceed total duration
    self.totalDuration = totalDuration // Set the total duration
  }

  func draw(layout: Text.Layout, in context: inout GraphicsContext) {
    // Draw the text layout in the graphics context
    let delay = elementDelay(count: layout.count) // Calculate the delay between elements

    for (i, line) in layout.enumerated() {
      // Iterate over each line in the layout
      let timeOffset = TimeInterval(i) * delay // Calculate the time offset for the current line
      let elementTime = max(0, min(elapsedTime - timeOffset, elementDuration)) // Calculate the animation time for the current line

      var copy = context // Create a copy of the graphics context
      draw(line, at: elementTime, in: &copy) // Draw the current line
    }
  }

  var spring: Spring {
    // Create a spring animation with snappy effect
    .snappy(duration: elementDuration - 0.05, extraBounce: 0.4)
  }

  func draw(
    _ line: Text.Layout.Line,
    at time: TimeInterval,
    in context: inout GraphicsContext
  ) {
    // Draw a single line of text layout
    let progress = time / elementDuration // Calculate the progress of the animation
    let fadeInProgress = UnitCurve.easeOut.value(at: progress)
    let opacity = fadeInProgress * UnitCurve.easeIn.value(at: 1.4 * progress) // Calculate the opacity based on progress
    let blurRadius = line.typographicBounds.rect.height / 16 * UnitCurve.easeIn.value(at: 1 - progress) // Calculate the blur radius based on progress
    let translationY = spring.value(fromValue: -line.typographicBounds.descent, toValue: 0, initialVelocity: 0, time: time) // Calculate the y-axis translation

    context.opacity = opacity // Set the context opacity
    context.addFilter(.blur(radius: blurRadius)) // Add blur filter to the context
    context.translateBy(x: 0, y: translationY) // Translate the context
    context.draw(line, options: .disablesSubpixelQuantization) // Draw the line of text
  }

  /// Calculates how much time passes between the start of two consecutive
  /// element animations.
  ///
  /// For example, if there's a total duration of 1 s and an element
  /// duration of 0.5 s, the delay for two elements is 0.5 s.
  /// The first element starts at 0 s, and the second element starts at 0.5 s
  /// and finishes at 1 s.
  ///
  /// However, to animate three elements in the same duration,
  /// the delay is 0.25 s, with the elements starting at 0.0 s, 0.25 s,
  /// and 0.5 s, respectively.
  func elementDelay(count: Int) -> TimeInterval {
    let count = TimeInterval(count) // Convert element count to time interval
    let remainingTime = totalDuration - count * elementDuration // Calculate the remaining time

    let delay = max(remainingTime / (count + 1), (totalDuration - elementDuration) / count) // Calculate the delay between elements
    return delay // Return the calculated delay
  }
}

extension Text.Layout {
  var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
    // Flatten the lines into runs
    flatMap { line in
      line
    }
  }

  var flattenedRunSlices: some RandomAccessCollection<Text.Layout.RunSlice> {
    // Flatten the runs into run slices
    flattenedRuns.flatMap(\.self)
  }
}

struct LineByLineTransition: Transition {
  let duration: TimeInterval
  init(duration: TimeInterval = 1.0) {
    self.duration = duration
  }

  func body(content: Content, phase: TransitionPhase) -> some View {
    let elapsedTime = phase.isIdentity ? duration : 0
    let renderer = LineByLineEffect(
      elapsedTime: elapsedTime,
      totalDuration: duration
    )

  return content
      .textRenderer(renderer)
      .transaction { t in
        if !t.disablesAnimations {
          t.animation = .linear(duration: duration)
        }
      }
  }
}

extension AnyTransition {
    @MainActor static func lineByLine(duration: TimeInterval = 1.0) -> AnyTransition {
        AnyTransition(LineByLineTransition(duration: duration))
    }
}
