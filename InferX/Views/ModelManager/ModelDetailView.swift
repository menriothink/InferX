//
//  ModelDetailView.swift
//  InferX
//
//  Created by Gemini on 2025/10/08.
//

import SwiftUI
import SwiftData

struct ModelDetailView: View {
    @Environment(ModelManagerModel.self) var modelManager
    
    let model: Model
    
    @State private var showingDeleteAlert = false

    var body: some View {
        Form {
            Section(header: Text("Model Information").font(.headline)) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 15) {
                    HStack {
                        Text("Model Provider")
                        Spacer()
                        matchedTab(modelProvider: model.modelProvider)?.iconView()
                            .padding(.leading, 10)
                        Text(model.modelProvider.rawValue)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Model Name")
                        Spacer()
                        Text(model.name)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .help(model.name)
                    }
                    
                    HStack {
                        Text("API")
                        Spacer()
                        Text(model.apiName)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Creation Date")
                        Spacer()
                        Text(model.createdAt.toFormatted(style: .long))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            
            let modelMeta = modelManager
                .remoteModels[model.apiName]?
                .filter({ $0.name == model.name })
                .first?.modelMeta
            
            Section(header: Text("Model Settings").font(.headline)) {
                ModelParameterView(
                    model: model,
                    modelMeta: modelMeta
                )
                .id(model.id)
                .disabled(modelMeta == nil)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(model.name)
        .overlay(alignment: .topLeading) {
            Button(action: {
                withAnimation(.easeInOut(duration: 1.0)) {
                    modelManager.selectedItem = .modelAPIDetail
                }
            }) {
                Image(systemName: "arrow.left")
            }
            .font(.title2)
            .padding(.top, -20)
            .padding(.leading, 20)
            .buttonStyle(DarkenOnPressButtonCircleStyle())
        }
        .transition(.move(edge: .trailing))
    }
}

