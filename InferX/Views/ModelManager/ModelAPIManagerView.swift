//
//  ConversationView.swift
//  InferX
//
//  Created by mingdw on 2025/4/13.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct ModelAPIManagerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(ModelManagerModel.self) var managerModel
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(\.openWindow) private var openWindow
    @State private var showingSettings = false
    @State private var showAddModelSheet = false
    @State private var showAddModelAPISheet = false

    var body: some View {
        Group {
            #if os(iOS)
            NavigationStack {
                if managerModel.modelAPIs.isEmpty {
                    ModelAPIDefaultView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.large)
                } else {
                    List {
                        Section("Model API") {
                            ForEach(managerModel.modelAPIs) { modelAPI in
                                NavigationLink {
                                    ModelAPIDetailView(modelAPI: modelAPI)
                                        .id(modelAPI.id)
                                        .navigationTitle(modelAPI.name)
                                        .navigationBarTitleDisplayMode(.inline)
                                        .onAppear {
                                            managerModel.activeModelAPI = modelAPI
                                            managerModel.selectedItem = .modelAPIDetail
                                        }
                                } label: {
                                    ModelAPISidebarItem(modelAPI: modelAPI)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        managerModel.deleteModelAPI(modelAPI: modelAPI)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        Section("Actions") {
                            Button {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    settingsModel.selectedItem = .conversation
                                    conversationModel.createConversation()
                                }
                            } label: {
                                Label("New Conversation", systemImage: "plus.bubble")
                            }

                            Button {
                                showAddModelSheet = true
                            } label: {
                                Label("Add Model", systemImage: "plus")
                            }

                            Button {
                                showAddModelAPISheet = true
                            } label: {
                                Label("Add Model API", systemImage: "square.and.arrow.down")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                settingsModel.selectedItem = .conversation
                            }) {
                                Image(systemName: "arrow.uturn.backward.circle.badge.ellipsis")
                            }
                        }
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gear")
                            }
                            Button {
                                settingsModel.selectedItem = .conversation
                            } label: {
                                Text("Done")
                            }
                        }
                    }
                    .toolbar(.visible, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color(.systemBackground), for: .navigationBar)
                }
            }
            #if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Swipe right to go back to conversation
                        if value.translation.width > 80 && abs(value.translation.height) < abs(value.translation.width) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                settingsModel.selectedItem = .conversation
                            }
                        }
                    }
            )
            #endif
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environment(settingsModel)
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, layoutDirection)
            }
            .sheet(isPresented: $showAddModelSheet) {
                ModelAddSheetView()
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, layoutDirection)
            }
            .sheet(isPresented: $showAddModelAPISheet) {
                ModelAPIAddSheetView()
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, layoutDirection)
            }
            #else
            ZStack(alignment: .top) {
                #if os(macOS)
                if !managerModel.modelAPIs.isEmpty {
                    Color.clear.frame(height: 50)
                        .background(DraggableArea())
                }
                #endif

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
                            #if os(iOS)
                            .padding(.leading, 12)
                            #else
                            .padding(.leading, 80)
                            #endif
                            .font(.title2)
                            
                            Spacer()
                            
                            ModelAPISidebar()
                                #if os(macOS)
                                .frame(width: 150)
                                #else
                                .frame(maxWidth: .infinity)
                                #endif
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
            #endif
        }
        .transition(.move(edge: .leading))
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(settingsModel)
        }
    }

    private func toggleSettingsWindow() {
        #if os(macOS)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "Settings" }) {
            if window.isKeyWindow {
                window.close()
            } else {
                openWindow(id: "Settings")
            }
        } else {
            openWindow(id: "Settings")
        }
        #else
        showingSettings = true
        #endif
    }
}
