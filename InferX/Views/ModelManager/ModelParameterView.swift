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
        VStack(alignment: .leading) {
            Text("Model Prompt")
            
            TextEditor(text: Binding(
                get: { model.systemPrompt },
                set: { model.systemPrompt = $0 }
            ))
            .font(.system(size: 13))
            .cornerRadius(4)
            .multilineTextAlignment(.leading)
            .frame(minHeight: 50)
        }
          
        Form {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 12) {
                HStack {
                    HStack {
                        Text("Temperature")
                        Spacer()
                    }
                    .frame(width: textWidth)

                    Slider(
                        value: Binding(
                            get: { model.temperature },
                            set: { model.temperature = $0 }
                        ),
                        in: temperatureRange
                    )
                    
                    Text("\(model.temperature, specifier: "%.2f")")
                        .frame(width: sliderTextWidth, alignment: .trailing)
                }
                .help("Sampling temperature.")
                
                HStack {
                    HStack {
                        Text("Top P")
                        Spacer()
                    }
                    .frame(width: textWidth)
                    
                    Slider(
                        value: Binding(
                            get: { model.topP },
                            set: { model.topP = $0 }
                        ),
                        in: 0.0...1.0
                    )
                    
                    Text("\(model.topP, specifier: "%.2f")")
                        .frame(width: sliderTextWidth, alignment: .trailing)
                }
                .frame(alignment: .leading)
                .help("Select from the most probable tokens whose sum sampling rate is P.")
                
                if model.enableTopK {
                    HStack {
                        HStack {
                            Text("Top K")
                            Spacer()
                        }
                        .frame(width: textWidth)

                        TextField("", value: Binding(
                            get: {
                                model.topK
                            },
                            set: {
                                if $0 > 0 {
                                    model.topK = $0
                                } else {
                                    model.topK = 0
                                }
                            }
                        ), formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                        
                        Text("").frame(width: sliderTextWidth)
                    }
                    .help("Sample from K most probable tokens.")
                }
                
                if model.enableSeed {
                    HStack {
                        HStack {
                            Text("Seed")
                            Spacer()
                        }
                        .frame(width: textWidth)
                        
                        TextField("", value: Binding(
                            get: {
                                model.seed
                            },
                            set: {
                                if $0 > 0 {
                                    model.seed = $0
                                } else {
                                    model.seed = 0
                                }
                            }
                        ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        
                        Text("").frame(width: sliderTextWidth)
                    }
                    .help("Optional integer to set the seed for random generations, for consistency. Useful for testing or reproducing results.")
                }
                
                if model.enableRepetitionPenalty {
                    HStack {
                        HStack {
                            Text("Repetition Penalty")
                            Spacer()
                        }
                        .frame(width: textWidth)
                        
                        Slider(
                            value: Binding(
                                get: { model.repetitionPenalty },
                                set: { model.repetitionPenalty = $0 }
                            ),
                            in: 0.1...2.0
                        )
                        
                        Text("\(model.repetitionPenalty, specifier: "%.2f")")
                            .frame(width: sliderTextWidth, alignment: .trailing)
                    }
                    .help("A penalty applied to tokens that have already been generated. 1.0 is no penalty. Greater than 1.0 penalizes, less than 1.0 ‘encourages’.")
                }
                
                HStack {
                    HStack {
                        Text("History Messages")
                        Spacer()
                    }
                    .frame(width: textWidth)
                    
                    TextField("", value: Binding(
                        get: {
                            model.inputMessages
                        },
                        set: {
                            if $0 > 0 {
                                model.inputMessages = $0
                            } else {
                                model.inputMessages = 0
                            }
                        }
                    ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                    Spacer()
                    Text("").frame(width: sliderTextWidth)
                }
                .help("Number of historical messages to carry when sending new messages to the model. Recommended range 0-50.")
                
                if let inputTokenLimit = modelMeta?.inputTokenLimit {
                    HStack {
                        HStack {
                            Text("Input Tokens Limit")
                            Spacer()
                        }
                        .frame(width: textWidth)
                        
                        TextField("", value: Binding(
                            get: {
                                model.inputTokens
                            },
                            set: {
                                if $0 > inputTokenLimit {
                                    model.inputTokens = inputTokenLimit
                                } else if $0 < 0 {
                                    model.inputTokens = 0
                                } else {
                                    model.inputTokens = $0
                                }
                            }
                        ), formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        
                        Text("").frame(width: sliderTextWidth)
                    }
                    .help("Limit the total number of input tokens for the model (including historical messages and current input). Max: \(inputTokenLimit).")
                }
                
                if let outputTokenLimit = modelMeta?.outputTokenLimit {
                    HStack {
                        HStack {
                            Text("Generation Tokens")
                            Spacer()
                        }
                        .frame(width: textWidth)
                           
                        TextField("", value: Binding(
                            get: {
                                model.outputTokens
                            },
                            set: {
                                if $0 > outputTokenLimit {
                                    model.outputTokens = outputTokenLimit
                                } else if $0 < 0 {
                                    model.outputTokens = 0
                                } else {
                                    model.outputTokens = $0
                                }
                            }
                        ), formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                        
                        Text("").frame(width: sliderTextWidth)
                    }
                    .help("Limit the number of tokens generated by the model. Max: \(outputTokenLimit).")
                }
            }
        }
    }
}

