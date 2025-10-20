import SwiftUI

struct MLXCommunityView: View {
    @Environment(ModelManagerModel.self) var modelManager

    let modelAPI: ModelAPIDescriptor
    
    @State private var remoteHFModels: [RemoteHFModel] = []
    @State private var modelsFetchError = ""
    @State private var searchQuery = ""
    @State private var isFetching = false
    @State private var isFetchingForScan = false
    @State private var sortValue: String = "downloads"
    @State private var direction: String = "-1"
    @State private var isHovering = false
    @State private var loadThreshold = 5
    @State private var lastLoadTriggerIndex = -1
    
    var body: some View {
        VStack(alignment: .leading) {
            
            modelHeaderView
            
            Text(modelsFetchError)
                .foregroundStyle(.red)

            modelListView

            Spacer()
        }
        .foregroundColor(Color(.controlTextColor))
        .accentColor(Color(.controlAccentColor))
        .task(id: SearchKey(c: sortValue, d: direction)) {
            await fetchModels()
        }
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
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .buttonStyle(DarkenOnPressButtonCircleStyle())
        .transition(.move(edge: .trailing))
    }

    @ViewBuilder
    private var modelHeaderView: some View {
        Text("Community Model List").font(.headline)
            .padding(.top, 20)

        HStack {
            TextField("Search...", text: $searchQuery)
                .textFieldStyle(.plain)
                .padding(5)
                .frame(height: 30)
                .onHover { isHovering = $0 }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHovering ? Color(.gray).opacity(0.3) : Color(.gray).opacity(0.1))
                )
                .animation(.easeInOut(duration: 0.2), value: isHovering)
                .onSubmit {
                    Task {
                        await fetchModels()
                    }
                }

            Spacer()

            Menu {
                Button("Sort by Downloads", action: {
                    direction = "-1"
                    sortValue = "downloads"
                })

                Button("Sort by ❤️", action: {
                    direction = "-1"
                    sortValue = "likes"
                })

                Button("Sort by Time \(direction == "-1" ? "Ascending" : "Descending")", action: {
                    direction = direction == "1" ? "-1" : "1"
                    sortValue = "createdAt"
                })
            } label: {
                Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
            }
        }
        .disabled(isFetching)
    }
    
    @ViewBuilder
    private var modelListView: some View {
        ScrollView {
            LazyVStack {
                ForEach(remoteHFModels.indices, id: \.self) { index in
                    MLXCommunityItemView(modelAPI: modelAPI, remoteHFModel: $remoteHFModels[index])
                        .onAppear {
                            checkLoadMore(for: index)
                        }
                }

                if isFetching {
                    ProgressView()
                        .frame(height: 50)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.4))
        )
    }
    
    private func fetchModels(search: String? = nil, needMore: Bool = false) async {
        guard !isFetching else { return }
        isFetching = true

        do {
            var remoteHFModels: [RemoteHFModel] = []
            if !needMore {
                remoteHFModels = try await modelManager.hfModelListModel.getRemoteHFModels(
                    modelAPI: modelAPI,
                    searchQuery: searchQuery,
                    sortValue: sortValue,
                    direction: direction
                )
            } else {
                remoteHFModels = try await modelManager.hfModelListModel.getRemoteHFModels(
                    modelAPI: modelAPI,
                    loadMore: true
                )
            }
            
            if !needMore {
                self.remoteHFModels = remoteHFModels
            } else {
                self.remoteHFModels.append(contentsOf: remoteHFModels)
            }
            modelsFetchError = ""
        } catch {
            modelsFetchError = error.localizedDescription
        }

        isFetching = false
    }

    private func checkLoadMore(for index: Int) {
        let shouldLoad = index >= self.remoteHFModels.count - loadThreshold &&
                        index > lastLoadTriggerIndex &&
                        !isFetching

        guard shouldLoad else { return }

        lastLoadTriggerIndex = index

        Task {
            await fetchModels(needMore: true)
        }
    }
}

struct DarkenOnPressButtonCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .background(Circle()
                .fill(.gray.opacity(configuration.isPressed ? 0.5 : 0))
                .frame(width: 25, height: 25)
            )
    }
}

