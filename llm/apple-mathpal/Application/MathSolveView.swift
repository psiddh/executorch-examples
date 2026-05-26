/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import SwiftUI

struct MathSolveView: View {
  @ObservedObject var viewModel: MathViewModel
  var onSolve: (String) -> Void

  @State private var inputText = ""

  var body: some View {
    VStack(spacing: 0) {
      inputBar
        .padding()

      Divider()

      if viewModel.steps.isEmpty && !viewModel.isGenerating {
        emptyState
      } else {
        stepsContent
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Input Bar

  @ViewBuilder
  private var inputBar: some View {
    HStack(spacing: 8) {
      TextField("Ask any math problem...", text: $inputText)
        .textFieldStyle(.roundedBorder)
        .onSubmit {
          submitQuestion()
        }

      if viewModel.isGenerating {
        Button(action: { viewModel.stopGeneration() }) {
          Image(systemName: "stop.circle.fill")
            .font(.title2)
            .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .help("Stop generating")
      } else {
        Button(action: { submitQuestion() }) {
          Image(systemName: "paperplane.fill")
            .font(.title2)
            .foregroundColor(inputText.isEmpty ? .gray : .accentColor)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty)
        .help("Send")
      }
    }
  }

  // MARK: - Empty State

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "function")
        .font(.system(size: 40))
        .foregroundColor(.secondary.opacity(0.5))
      Text("Type a math problem or pick one from the sidebar")
        .font(.title3)
        .foregroundColor(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Steps Content

  @ViewBuilder
  private var stepsContent: some View {
    VStack(spacing: 0) {
      if !viewModel.currentQuestion.isEmpty {
        questionHeader
      }

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
              stepCard(index: index, step: step)
                .id(step.id)
            }

            if viewModel.isGenerating {
              thinkingIndicator
                .id("thinking")
            }
          }
          .padding()
        }
        .onChange(of: viewModel.steps.count) { _ in
          if let lastStep = viewModel.steps.last {
            withAnimation(.easeOut(duration: 0.2)) {
              proxy.scrollTo(lastStep.id, anchor: .bottom)
            }
          }
        }
      }

      if !viewModel.isGenerating && !viewModel.steps.isEmpty {
        bottomBar
      }
    }
  }

  // MARK: - Question Header

  @ViewBuilder
  private var questionHeader: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Problem")
        .font(.caption)
        .fontWeight(.bold)
        .foregroundColor(.accentColor)
      Text(viewModel.currentQuestion)
        .font(.title3)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(NSColor.controlBackgroundColor))

    Divider()
  }

  // MARK: - Step Card

  @ViewBuilder
  private func stepCard(index: Int, step: StepState) -> some View {
    HStack(alignment: .top, spacing: 12) {
      if step.isAnswer {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundColor(.white)
      } else {
        Text("\(index + 1)")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundColor(.white)
          .frame(width: 24, height: 24)
          .background(Circle().fill(Color.accentColor))
      }

      Text(step.text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(step.isAnswer ? .white : .primary)
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(step.isAnswer ? Color.blue : Color(NSColor.controlBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(step.isAnswer ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Thinking Indicator

  @ViewBuilder
  private var thinkingIndicator: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
      Text("Thinking...")
        .font(.body)
        .foregroundColor(.accentColor)
        .fontWeight(.medium)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }

  // MARK: - Bottom Bar

  @ViewBuilder
  private var bottomBar: some View {
    Divider()
    HStack(spacing: 12) {
      Button(action: {
        viewModel.newProblem()
      }) {
        Label("Got It", systemImage: "checkmark")
      }
      .buttonStyle(.borderedProminent)

      Button(action: {
        viewModel.newProblem()
        inputText = ""
      }) {
        Label("New Problem", systemImage: "arrow.counterclockwise")
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Helpers

  private func submitQuestion() {
    let q = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return }
    inputText = ""
    onSolve(q)
  }
}
