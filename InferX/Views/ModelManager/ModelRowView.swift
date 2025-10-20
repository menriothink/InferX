//
//  ModelRowView.swift
//  InferX
//
//  Created by mingdw on 2025/10/1.
//

import SwiftUI

struct ModelRowView: View {
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ModelManagerModel.self) var modelManager
    
    let model: Model
    let isSelectting: Bool
    
    var onSelectting: ((_ model: Model) -> Void)?
    
    @State private var isHovering = false
    @State private var showingDeleteTaskAlert = false

    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .controlSize(.mini)
                .foregroundStyle(model.isAvailable ? .green : .red)
                .font(.subheadline)
                .help("Model Status")
            
            Text(model.name)
                .font(.subheadline)
                .lineLimit(1)
                .help(model.fullName)
            
            Spacer()
            
            if isHovering || isSelectting {
                Button(action: {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        settingsModel.selectedItem = .modelAPIManager
                        modelManager.selectedItem = .modelDetail
                        modelManager.activeModel = model
                        modelManager.activeModelAPI = modelManager.modelAPIs.first {
                            $0.name == model.apiName
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 8)
                }
                .font(.subheadline)
                
                Button(action: { showingDeleteTaskAlert = true }) {
                    Image(systemName: "trash")
                        .renderingMode(.original)
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal, 12)
        .buttonStyle(ToolbarIconButtonStyle())
        .background((isHovering || isSelectting) ? Color.primary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelectting?(model)
        }
        .contextMenu {
            Button(role: .destructive, action: {
                showingDeleteTaskAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteTaskAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: {
                modelManager.deleteModel(model: model)
            })
        } message: {
            Text("Are you sure you want to delete the current Model? \(model.name)")
        }
    }
}

