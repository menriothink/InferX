//
//  ModelParameterView.swift
//  InferX
//
//  Created by mingdw on 2025/9/28.
//

import SwiftUI
import SwiftData

struct ModelParameterView: View {
    @Environment(ModelManagerModel.self) var modelManager
        
    let model: Model
    let modelMeta: ModelMeta?
    
    private let textWidth: CGFloat = 120
    private let sliderWidth: CGFloat = 220
    private let sliderTextWidth: CGFloat = 50
    
    private var temperatureRange: ClosedRange<Float> {
        let maxTemp = modelMeta?.maxTemperature ?? 2.0
        return 0.1...maxTemp
    }
    
    var body: some View {
        Section(header: Text("Model Settings").font(.headline)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Model Prompt")
                    .font(.subheadline.weight(.medium))
                
                TextEditor(text: Binding(
                    get: { model.systemPrompt },
                    set: { model.systemPrompt = $0 }
                ))
                .font(.system(size: 13))
                .multilineTextAlignment(.leading)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.vertical, 4)
            
            VStack(spacing: 12) {
                parameterRow(
                    title: "Temperature",
                    help: "Sampling temperature."
                ) {
                    sliderRow(
                        value: Binding(
                            get: { model.temperature },
                            set: { model.temperature = $0 }
                        ),
                        in: temperatureRange,
                        displayText: String(format: "%.2f", model.temperature)
                    )
                }
                
                parameterRow(
                    title: "Top P",
                    help: "Select from the most probable tokens whose sum sampling rate is P."
                ) {
                    sliderRow(
                        value: Binding(
                            get: { model.topP },
                            set: { model.topP = $0 }
                        ),
                        in: 0.0...1.0,
                        displayText: String(format: "%.2f", model.topP)
                    )
                }
                
                if model.enableTopK {
                    parameterRow(title: "Top K", help: "Sample from K most probable tokens.") {
                        TextField("", value: Binding(
                            get: { model.topK },
                            set: { model.topK = max(0, $0) }
                        ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    }
                }
                
                if model.enableSeed {
                    parameterRow(
                        title: "Seed",
                        help: "Optional integer to set the seed for random generations, for consistency. Useful for testing or reproducing results."
                    ) {
                        TextField("", value: Binding(
                            get: { model.seed },
                            set: { model.seed = max(0, $0) }
                        ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    }
                }
                
                if model.enableRepetitionPenalty {
                    parameterRow(
                        title: "Repetition Penalty",
                        help: "A penalty applied to tokens that have already been generated. 1.0 is no penalty. Greater than 1.0 penalizes, less than 1.0 ‘encourages’."
                    ) {
                        sliderRow(
                            value: Binding(
                                get: { model.repetitionPenalty },
                                set: { model.repetitionPenalty = $0 }
                            ),
                            in: 0.1...2.0,
                            displayText: String(format: "%.2f", model.repetitionPenalty)
                        )
                    }
                }
                
                parameterRow(
                    title: "History Messages",
                    help: "Number of historical messages to carry when sending new messages to the model. Recommended range 0-50."
                ) {
                    TextField("", value: Binding(
                        get: { model.inputMessages },
                        set: { model.inputMessages = max(0, $0) }
                    ), formatter: NumberFormatter())
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                }
                
                if let inputTokenLimit = modelMeta?.inputTokenLimit {
                    parameterRow(
                        title: "Input Tokens Limit",
                        help: "Limit the total number of input tokens for the model (including historical messages and current input). Max: \(inputTokenLimit)."
                    ) {
                        TextField("", value: Binding(
                            get: { model.inputTokens },
                            set: { model.inputTokens = min(max(0, $0), inputTokenLimit) }
                        ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    }
                }
                
                if let outputTokenLimit = modelMeta?.outputTokenLimit {
                    parameterRow(
                        title: "Generation Tokens",
                        help: "Limit the number of tokens generated by the model. Max: \(outputTokenLimit)."
                    ) {
                        TextField("", value: Binding(
                            get: { model.outputTokens },
                            set: { model.outputTokens = min(max(0, $0), outputTokenLimit) }
                        ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func parameterRow<Content: View>(
        title: LocalizedStringKey,
        help: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .help(help ?? "")
    }
    
    @ViewBuilder
    private func sliderRow(
        value: Binding<Float>,
        in range: ClosedRange<Float>,
        displayText: String
    ) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range)
            Text(displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

