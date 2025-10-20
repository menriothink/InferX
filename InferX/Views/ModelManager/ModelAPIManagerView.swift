//
//  ConversationView.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import SwiftUI
import SwiftData

struct ModelAPIManagerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ModelManagerModel.self) var managerModel
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            ZStack(alignment: .top) {
                if !managerModel.modelAPIs.isEmpty {
                    Color.clear.frame(height: 50)
                        .background(DraggableArea())
                }

                HStack(spacing: 0) {
                    if !managerModel.modelAPIs.isEmpty {
                        VStack {
                            HStack {
                                Button(action: {
                                    settingsModel.selectedItem = .conversation
                                }) {
                                    Image(systemName: "arrow.uturn.backward.circle.badge.ellipsis")
                                }
                                
                                Button {
                                    toggleSettingsWindow()
                                } label: {
                                    Image(systemName: "gear")
                                }
                                .padding(.leading, 10)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                            .padding(.leading, 80)
                            .font(.title2)
                            
                            Spacer()
                            
                            ModelAPISidebar()
                                .frame(width: 150)
                                .padding(.top, 20)
                        }
                        
                        Group {
                            if let modelAPI = managerModel.activeModelAPI {
                                switch managerModel.selectedItem {
                                case .modelAPIDetail:
                                    ModelAPIDetailView(modelAPI: modelAPI)
                                        .id(modelAPI.id)
                                case .modelDetail:
                                    if let activeModel = managerModel.activeModel {
                                        ModelDetailView(model: activeModel)
                                            .id(activeModel.id)
                                    }
                                case .hfModelListView:
                                    HFModelListView(modelAPI: ModelAPIDescriptor(from: modelAPI))
                                        .id(modelAPI.id)
                                case .mlxView:
                                    MLXCommunityView(modelAPI: ModelAPIDescriptor(from: modelAPI))
                                        .id(modelAPI.id)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 30)
                    } else {
                        ModelAPIDefaultView()
                    }
                }
            }
        }
        .transition(.move(edge: .leading))
    }

    private func toggleSettingsWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "Settings" }) {
            if window.isKeyWindow {
                window.close()
            } else {
                openWindow(id: "Settings")
            }
        } else {
            openWindow(id: "Settings")
        }
    }
}
