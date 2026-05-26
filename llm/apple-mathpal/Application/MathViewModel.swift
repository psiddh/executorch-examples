/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import ExecuTorchLLM
import SwiftUI

struct StepState: Identifiable {
  let id = UUID()
  var text: String
  var isAnswer: Bool = false
}

class MathViewModel: ObservableObject {
  @Published var steps: [StepState] = []
  @Published var finalAnswer: String?
  @Published var isGenerating = false
  @Published var currentQuestion = ""
  @Published var isModelLoaded = false
  @Published var loadingMessage: String?

  private var responseAccumulator = ""
  private var currentStepText = ""
  private var sawHashMarker = false
  private var hashTokenCount = 0
  private var shouldStop = false

  private static let systemPrompt =
    "You are a helpful math tutor for 8th graders. " +
    "Solve problems step by step. " +
    "Put your final numeric answer after ####."

  func solve(question: String, runner: TextRunner, queue: DispatchQueue) {
    guard isModelLoaded, !isGenerating else { return }

    currentQuestion = question
    steps = []
    finalAnswer = nil
    responseAccumulator = ""
    currentStepText = ""
    sawHashMarker = false
    hashTokenCount = 0
    shouldStop = false
    isGenerating = true

    let prompt =
      "<|im_start|>system\n" +
      "\(Self.systemPrompt)<|im_end|>\n" +
      "<|im_start|>user\n" +
      "\(question)<|im_end|>\n" +
      "<|im_start|>assistant\n"

    queue.async { [weak self] in
      defer {
        DispatchQueue.main.async {
          self?.isGenerating = false
          self?.flushCurrentStep()
          self?.extractFinalAnswerIfNeeded()
          if let s = self, s.steps.isEmpty, !s.responseAccumulator.isEmpty {
            let cleaned = s.responseAccumulator
              .replacingOccurrences(of: "<think>", with: "")
              .replacingOccurrences(of: "</think>", with: "")
              .replacingOccurrences(of: "<|im_end|>", with: "")
              .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
              s.steps.append(StepState(text: cleaned))
            }
          }
        }
      }

      do {
        try runner.generate(prompt, Config {
          $0.sequenceLength = 512
        }) { [weak self] token in
          guard let self else { return }
          if self.shouldStop {
            runner.stop()
            return
          }
          DispatchQueue.main.async {
            self.handleToken(token, runner: runner)
          }
        }
      } catch {
        DispatchQueue.main.async {
          self?.steps.append(StepState(text: "Generation failed: \((error as NSError).code)"))
        }
      }

      runner.reset()
    }
  }

  func stopGeneration() {
    shouldStop = true
  }

  func newProblem() {
    steps = []
    finalAnswer = nil
    currentQuestion = ""
    responseAccumulator = ""
    currentStepText = ""
    isGenerating = false
    sawHashMarker = false
    hashTokenCount = 0
  }

  // MARK: - Token handling

  private func handleToken(_ token: String, runner: TextRunner) {
    guard finalAnswer == nil else { return }

    responseAccumulator += token

    if token == "<think>" || token == "</think>" {
      return
    }

    if token == "<|im_end|>" {
      shouldStop = true
      flushCurrentStep()
      extractFinalAnswerIfNeeded()
      return
    }

    if !sawHashMarker && responseAccumulator.contains("####") {
      sawHashMarker = true
      hashTokenCount = 0
    }

    if sawHashMarker {
      hashTokenCount += 1
      if hashTokenCount >= 10 && finalAnswer == nil {
        extractHashAnswer()
      }
      return
    }

    let trimmed = token.trimmingCharacters(in: .whitespaces)
    let startsNewStep =
      trimmed.range(of: #"^Step \d+"#, options: .regularExpression) != nil ||
      trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil ||
      (token.contains("\n\n") && !currentStepText.isEmpty)

    if startsNewStep {
      flushCurrentStep()
      currentStepText = trimmed
    } else {
      currentStepText += token
      updateLiveStep()
    }
  }

  private func flushCurrentStep() {
    let text = currentStepText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    if let lastIdx = steps.lastIndex(where: { !$0.isAnswer }) {
      if steps[lastIdx].text != text {
        steps[lastIdx] = StepState(text: text)
      }
    } else {
      steps.append(StepState(text: text))
    }
    currentStepText = ""
  }

  private func updateLiveStep() {
    let text = currentStepText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    if let lastIdx = steps.lastIndex(where: { !$0.isAnswer }) {
      steps[lastIdx] = StepState(text: text)
    } else {
      steps.append(StepState(text: text))
    }
  }

  private func extractHashAnswer() {
    let fullText = responseAccumulator
    guard let range = fullText.range(of: #"####\s*([\d.,/\-]+)"#, options: .regularExpression) else { return }
    let match = fullText[range]
    let answer = match.replacingOccurrences(of: "####", with: "").trimmingCharacters(in: .whitespaces)
    guard !answer.isEmpty else { return }

    flushCurrentStep()

    if let lastIdx = steps.lastIndex(where: { !$0.isAnswer }) {
      let cleaned = steps[lastIdx].text
        .replacingOccurrences(of: #"####.*"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if cleaned.isEmpty {
        steps.remove(at: lastIdx)
      } else {
        steps[lastIdx] = StepState(text: cleaned)
      }
    }

    finalAnswer = answer
    steps.append(StepState(text: "Answer: \(answer)", isAnswer: true))
    shouldStop = true
  }

  private func extractFinalAnswerIfNeeded() {
    guard finalAnswer == nil else { return }
    let text = responseAccumulator
    guard let range = text.range(of: #"####\s*([\d.,/\-]+)"#, options: .regularExpression) else { return }
    let match = text[range]
    let answer = match.replacingOccurrences(of: "####", with: "").trimmingCharacters(in: .whitespaces)
    guard !answer.isEmpty else { return }

    finalAnswer = answer
    if !steps.contains(where: { $0.isAnswer }) {
      steps.append(StepState(text: "Answer: \(answer)", isAnswer: true))
    }
  }
}
