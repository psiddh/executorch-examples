/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import ExecuTorchLLM
import SwiftUI
import UniformTypeIdentifiers

class RunnerHolder: ObservableObject {
  var textRunner: TextRunner?
}

struct ContentView: View {
  @StateObject private var runnerHolder = RunnerHolder()
  @StateObject private var resourceManager = ResourceManager()
  @StateObject private var viewModel = MathViewModel()
  @State private var selectedGrade: Int = 8
  @State private var pickerType: PickerType?
  @State private var showingLogs = false
  @StateObject private var logManager = LogManager()
  @StateObject private var resourceMonitor = ResourceMonitor()
  private let runnerQueue = DispatchQueue(label: "org.pytorch.executorch.mathpal")

  enum PickerType {
    case model
    case tokenizer
  }

  private var isInputEnabled: Bool {
    resourceManager.isModelValid && resourceManager.isTokenizerValid && viewModel.isModelLoaded
  }

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
    } detail: {
      detailView
    }
    .navigationTitle("MathPal \u{2014} Math Tutor")
    .sheet(isPresented: $showingLogs) {
      logsSheet
    }
    .fileImporter(
      isPresented: Binding<Bool>(
        get: { pickerType != nil },
        set: { if !$0 { pickerType = nil } }
      ),
      allowedContentTypes: allowedContentTypes(),
      allowsMultipleSelection: false
    ) { [pickerType] result in
      handleFileImportResult(pickerType, result)
    }
    .onAppear {
      try? resourceManager.createDirectoriesIfNeeded()
      resourceMonitor.start()
    }
    .onDisappear {
      resourceMonitor.stop()
    }
  }

  // MARK: - Sidebar

  @ViewBuilder
  private var sidebar: some View {
    List {
      Section("Model") {
        Button(action: { pickerType = .model }) {
          HStack {
            Image(systemName: "cpu")
            Text(resourceManager.isModelValid ? resourceManager.modelName : "Select Model...")
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
          }
        }
        .buttonStyle(.plain)

        Button(action: { pickerType = .tokenizer }) {
          HStack {
            Image(systemName: "doc.text")
            Text(resourceManager.isTokenizerValid ? resourceManager.tokenizerName : "Select Tokenizer...")
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
          }
        }
        .buttonStyle(.plain)

        if resourceManager.isModelValid && resourceManager.isTokenizerValid && !viewModel.isModelLoaded {
          Button(action: { loadModel() }) {
            HStack {
              Image(systemName: "bolt.fill")
              Text(viewModel.loadingMessage ?? "Load Model")
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(.orange)
        }

        if viewModel.isModelLoaded {
          Label("Model Ready", systemImage: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.caption)
        }
      }

      Section("Grade Level") {
        ForEach(4...8, id: \.self) { grade in
          Button(action: { selectedGrade = grade }) {
            HStack {
              Text(gradeEmoji(grade))
              Text("Grade \(grade)")
                .fontWeight(selectedGrade == grade ? .bold : .regular)
              Spacer()
              if selectedGrade == grade {
                Image(systemName: "checkmark")
                  .foregroundColor(.accentColor)
              }
            }
          }
          .buttonStyle(.plain)
        }
      }

      Section("Problem Bank") {
        ProblemBankView(
          selectedGrade: selectedGrade,
          onSelect: { problem in
            if isInputEnabled {
              viewModel.solve(question: problem, runner: runnerHolder.textRunner!, queue: runnerQueue)
            }
          }
        )
      }

      Section("Info") {
        HStack {
          Text("Memory:")
          Spacer()
          Text("\(resourceMonitor.usedMemory) MB")
            .monospacedDigit()
            .foregroundColor(.secondary)
        }
        .font(.caption)

        Button(action: { showingLogs = true }) {
          Label("Logs", systemImage: "list.bullet.rectangle")
        }
        .buttonStyle(.plain)
      }
    }
    .listStyle(.sidebar)
  }

  // MARK: - Detail View

  @ViewBuilder
  private var detailView: some View {
    if !resourceManager.isModelValid || !resourceManager.isTokenizerValid {
      loadModelPrompt
    } else if !viewModel.isModelLoaded {
      VStack(spacing: 16) {
        Image(systemName: "brain")
          .font(.system(size: 48))
          .foregroundColor(.secondary)
        Text(viewModel.loadingMessage ?? "Load a model to start solving")
          .font(.title3)
          .foregroundColor(.secondary)
        Button("Load Model") { loadModel() }
          .buttonStyle(.borderedProminent)
          .tint(.orange)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      MathSolveView(viewModel: viewModel, onSolve: { question in
        viewModel.solve(question: question, runner: runnerHolder.textRunner!, queue: runnerQueue)
      })
    }
  }

  @ViewBuilder
  private var loadModelPrompt: some View {
    VStack(spacing: 20) {
      Image(systemName: "function")
        .font(.system(size: 64))
        .foregroundColor(.accentColor)

      Text("MathPal")
        .font(.largeTitle)
        .fontWeight(.bold)

      Text("Load a model to start solving math problems")
        .font(.title3)
        .foregroundColor(.secondary)

      HStack(spacing: 12) {
        Button(action: { pickerType = .model }) {
          Label(
            resourceManager.isModelValid ? resourceManager.modelName : "Select .pte Model",
            systemImage: "cpu"
          )
        }
        .buttonStyle(.borderedProminent)

        Button(action: { pickerType = .tokenizer }) {
          Label(
            resourceManager.isTokenizerValid ? resourceManager.tokenizerName : "Select Tokenizer",
            systemImage: "doc.text"
          )
        }
        .buttonStyle(.bordered)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Logs Sheet

  @ViewBuilder
  private var logsSheet: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Logs")
          .font(.headline)
        Spacer()
        Button(action: { logManager.clear() }) {
          Image(systemName: "trash")
        }
        .help("Clear logs")
        Button("Done") { showingLogs = false }
      }
      .padding()
      .background(Color(NSColor.controlBackgroundColor))

      Divider()

      LogView(logManager: logManager)
    }
    .frame(minWidth: 600, minHeight: 400)
  }

  // MARK: - Helpers

  private func gradeEmoji(_ grade: Int) -> String {
    switch grade {
    case 4: return "\u{2B50}"
    case 5: return "\u{1F4DA}"
    case 6: return "\u{1F9E0}"
    case 7: return "\u{26A1}"
    case 8: return "\u{1F525}"
    default: return "\u{1F4D6}"
    }
  }

  private func loadModel() {
    guard resourceManager.isModelValid && resourceManager.isTokenizerValid else { return }
    viewModel.loadingMessage = "Loading math brain..."

    runnerQueue.async {
      let runner = TextRunner(
        modelPath: resourceManager.modelPath,
        tokenizerPath: resourceManager.tokenizerPath
      )
      do {
        let start = Date()
        try runner.load()
        let duration = Date().timeIntervalSince(start)
        DispatchQueue.main.async {
          runnerHolder.textRunner = runner
          viewModel.isModelLoaded = true
          viewModel.loadingMessage = String(format: "Ready! (%.1fs)", duration)
        }
      } catch {
        DispatchQueue.main.async {
          viewModel.loadingMessage = "Failed to load: \((error as NSError).code)"
        }
      }
    }
  }

  private func allowedContentTypes() -> [UTType] {
    guard let pickerType else { return [] }
    switch pickerType {
    case .model:
      return [UTType(filenameExtension: "pte")].compactMap { $0 }
    case .tokenizer:
      return [UTType(filenameExtension: "bin"), UTType(filenameExtension: "model"), UTType(filenameExtension: "json")].compactMap { $0 }
    }
  }

  private func handleFileImportResult(_ pickerType: PickerType?, _ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first, let pickerType else { return }
      runnerQueue.async {
        DispatchQueue.main.async {
          runnerHolder.textRunner = nil
          viewModel.isModelLoaded = false
          viewModel.loadingMessage = nil
        }
      }
      switch pickerType {
      case .model:
        resourceManager.modelPath = url.path
      case .tokenizer:
        resourceManager.tokenizerPath = url.path
      }
    case .failure:
      break
    }
  }
}
