//
//  ModelManagerSidebarItem.swift
//  InferX
//
//  Created by mingdw on 2025/4/16.
//

import SwiftUI

struct ModelAPISidebarItem: View {
    @Environment(ModelManagerModel.self) var managerModel

    let modelAPI: ModelAPI

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var showingDeleteTaskAlert = false
    
    var body: some View {
        HStack(alignment: .center) {
            matchedTab(modelProvider: modelAPI.modelProvider)?.iconView()
                .padding(.leading, 5)
            
            Text(LocalizedStringKey(modelAPI.name))
                .font(.system(size: 12))
                .offset(x: 10)
                .lineLimit(1)
                .help("\(modelAPI.name) \(modelAPI.modelProvider.id)")

            Spacer()
            Circle()
                .foregroundStyle(modelAPI.isAvailable ? .green : .red)
                .frame(width: 4, height: 4)
                .shadow(color: .red, radius: 4)
                .padding(.trailing, 5)
        }
        .padding(.leading, 10)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background {
            if isActive || isHovering {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive || isHovering ? Color.gray.opacity(0.2) : Color.clear)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .task(id: managerModel.activeModelAPI) {
            checkIfSelfIsActiveTab()
        }
        .listRowSeparator(.hidden)
        .contextMenu {
            Button(role: .destructive, action: { showingDeleteTaskAlert = true }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.5)) {
                managerModel.activeModelAPI = modelAPI
                managerModel.selectedItem = .modelAPIDetail
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteTaskAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteModelAPI)
        } message: {
            Text("Are you sure you want to delete model API \(modelAPI.name)?")
        }
    }

    func checkIfSelfIsActiveTab() {
        withAnimation(.easeOut(duration: 0.1)) {
            isActive = managerModel.activeModelAPI == modelAPI
        }
    }
    
    private func deleteModelAPI() {
        managerModel.deleteModelAPI(modelAPI: modelAPI)
    }
}
