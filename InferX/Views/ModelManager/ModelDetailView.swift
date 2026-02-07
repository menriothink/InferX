//
//  ModelDetailView.swift
//  InferX
//
//  Created by Gemini on 2025/10/08.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

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
            
            let modelMeta = modelManager.getModelMeta(for: model)
            
            ModelParameterView(
                model: model,
                modelMeta: modelMeta
            )
            .id(model.id)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(model.name)
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        // iOS: Tap outside inputs to dismiss keyboard.
        .onTapGesture {
            dismissKeyboard()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
        #endif
        #if os(macOS)
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
        #endif
        .transition(.move(edge: .trailing))
    }
    
    #if os(iOS)
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    #endif
}

