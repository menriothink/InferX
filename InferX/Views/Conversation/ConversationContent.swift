//
//  ConversationContent.swift
//  InferX
//
//  Created by mingdw on 2025/4/22.
//

import SwiftUI
import SwiftData
import SwiftUIIntrospect
import AlertToast
import SwiftUIX
import Defaults

struct ScrollToInfo: Equatable {
    let messageID: PersistentIdentifier
    let anchor: UnitPoint
}

struct SearchKey: Equatable {
    let c: String
    let d: String
}

struct ScrollMetrics: Equatable {
    let offsetY: CGFloat
    let contentHeight: CGFloat
    let visibleRect: CGRect
}

struct ConversationContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ConversationDetailModel.self) private var detailModel

    @Default(.backgroundColorWhite) var backgroundColorWhite
    @Default(.backgroundColorBlack) var backgroundColorBlack

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var isFetching = false
    @State private var isTopLoading = false
    @State private var isBottomLoading = false
    @State private var isAtTop = false
    @State private var isAtBottom = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var direction = Direction.none
    @State private var firstMessageAppear = false
    @State private var lastMessageAppear = false
    @State private var showToast = false
    @State private var searchKey = SearchKey(c: "", d: "")
    @State private var scrollToBottomTimes = 0
    @State private var scrollPosition = ScrollPosition()
    @State private var loadedMessages: [MessageData] = []

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if let bottomMessage = detailModel.bottomMessage,
                       let lastLoadedMessage = loadedMessages.last {
                        ForEach(loadedMessages, id: \.id) { messageData in
                            if messageData.id != bottomMessage.id {
                                ConversationMessage(messageData: messageData, isBottomMessage: false)
                                    .id(messageData.id)
                                    .padding(.bottom, 50)
                            }
                        }

                        if bottomMessage.id == lastLoadedMessage.id {
                            ConversationMessage(messageData: bottomMessage, isBottomMessage: true)
                                .id(bottomMessage.id)
                        }
                    }
                }
                .scrollPosition($scrollPosition)
                .onAppear {
                    scrollProxy = proxy
                    if detailModel.searchText.isEmpty {
                        scrollToTopBottom(isToTop: false)
                    }
                }
                .onChange(of: detailModel.reLoadCurrentMessages) {
                    reLoadCurrentMessages()
                }
                .onChange(of: detailModel.scrollToTopMessage) {
                    scrollToTopBottom(isToTop: true)
                }
                .onChange(of: detailModel.scrollToBottomMessage) {
                    scrollToTopBottom(isToTop: false)
                }
                .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                    ScrollMetrics(
                        offsetY: geometry.contentOffset.y,
                        contentHeight: geometry.contentSize.height,
                        visibleRect: geometry.visibleRect
                    )
                } action: { oldScrollMetrics, newScrollMetrics in
                    handleScrollMetricsChange(old: oldScrollMetrics, new: newScrollMetrics)
                }
                .onScrollPhaseChange { _, phase in
                    scrollPhase = phase
                    if phase == .idle {
                        direction = .none
                    }
                }
                .toast(isPresenting: $showToast, duration: 2.5, offsetY: 30) {
                    AlertToast(
                        displayMode: .hud,
                        type: detailModel.toastType,
                        title: detailModel.toastMessage,
                        style:.style(backgroundColor: .gray.opacity(0.8), titleColor: .white)
                    )
                }
                .onChange(of: detailModel.showToast) {
                    showToast = true
                }
                .overlay {
                    if isFetching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .overlay(alignment: .bottom) {
                    ButtonToBottom()
                        .hidden(isAtBottom)
                        .animation(.easeOut(duration: 1.0), value: isAtBottom)
                }
                .task(id: SearchKey(c: conversationModel.searchText, d: detailModel.searchText)) {
                    searchKey = SearchKey(c: conversationModel.searchText, d: detailModel.searchText)
                }
            }

            Color.clear.overlay(alignment: .leading) {
                if settingsModel.sidebarState == .left {
                    ConversationSidebar()
                }
            }
            
            Color.clear.overlay(alignment: .trailing) {
                if settingsModel.sidebarState == .right {
                    ConversationRightSidebar()
                }
            }
        }
        .background(colorScheme == .dark ?
                    Color.black.opacity(backgroundColorBlack) : Color.white.opacity(backgroundColorWhite))
        .overlay(alignment: .top) {
            if detailModel.isSearching {
                SearchBarView(detailModel: detailModel)
                    .frame(minWidth: 150, maxWidth: 300)
            }
        }
    }

    private let offsetToContentBootom: CGFloat = 10
    private func setTopBottom(
        newContentHeight: CGFloat,
        oldContentOffsetY: CGFloat,
        newContentOffsetY: CGFloat,
        newVisibleRecHeight: CGFloat
    ) {
        if newContentOffsetY <= 0 {
            firstMessageAppear = true
        } else {
            firstMessageAppear = false
        }

        let isTopSameMessage = loadedMessages.first?.id == detailModel.topMessage?.id
        if firstMessageAppear, isTopSameMessage {
            isAtTop = true
        } else {
            isAtTop = false
        }

        let offset = abs(newContentHeight - (newContentOffsetY + newVisibleRecHeight))
        if offset <= offsetToContentBootom {
            lastMessageAppear = true
        } else {
            lastMessageAppear = false
        }

        if oldContentOffsetY > newContentOffsetY {
            isAtBottom = false
        }

        let isBottomSameMessage = loadedMessages.last?.id == detailModel.bottomMessage?.id
        if lastMessageAppear, isBottomSameMessage {
            isAtBottom = true
        }
    }

    private func handleScrollMetricsChange(old oldScrollMetrics: ScrollMetrics, new newScrollMetrics: ScrollMetrics) {
        let newContentOffsetY = newScrollMetrics.offsetY
        let oldContentOffsetY = oldScrollMetrics.offsetY
        let newContentHeight = newScrollMetrics.contentHeight
        let oldContentHeight = oldScrollMetrics.contentHeight
        let newVisibleRecHeight = newScrollMetrics.visibleRect.size.height

        detailModel.currentVisableHeight = newVisibleRecHeight

        setTopBottom(
            newContentHeight: newContentHeight,
            oldContentOffsetY: oldContentOffsetY,
            newContentOffsetY: newContentOffsetY,
            newVisibleRecHeight: newVisibleRecHeight
        )

        if scrollPhase != .idle {
            direction = newContentOffsetY > oldContentOffsetY ? .down : .up
        }

        if firstMessageAppear && direction == .up || lastMessageAppear && direction == .down {
            loadMoreMessages()
        }

        if isAtBottom, detailModel.inferring, newContentHeight > oldContentHeight {
            scrollPosition.scrollTo(edge: .bottom)
        }
    }

    private func loadMessages(
        from fetchFrom: FetchFrom,
        to endingDate: Date? = nil,
        direction: Direction? = nil,
        numbers: Int
    ) async -> [MessageData]? {
        if !isFetching {
            isFetching = true
        } else { return nil }

        defer {
            isFetching = false
        }

        let (topMessage, bottomMessage, newMessages) = await detailModel.fetchMessages(
            from: fetchFrom,
            to: endingDate,
            direction: direction,
            numbers: numbers,
            searchKey: searchKey
        )

        guard let newMessages, let topMessage, let bottomMessage else {
            return []
        }

        detailModel.topMessage = topMessage
        detailModel.bottomMessage = bottomMessage

        if endingDate != nil || fetchFrom == .top || fetchFrom == .bottom{
            timestampedLogger("Loaded new messages count: \(newMessages.count)", level: .debug)
            return newMessages
        }

        var loadedMessages = self.loadedMessages
        if loadedMessages.count - (detailModel.messagesPageSize + detailModel.messagesDropSize) > 0 {
            if direction == .up {
                loadedMessages.removeLast(detailModel.messagesDropSize)
            } else {
                loadedMessages.removeFirst(detailModel.messagesDropSize)
            }
        }

        if direction == .up {
            loadedMessages.insert(contentsOf: newMessages, at: 0)
        } else {
            loadedMessages.append(contentsOf: newMessages)
        }

        timestampedLogger("Loaded messages count: \(loadedMessages.count)", level: .debug)

        return loadedMessages
    }

    private func loadMoreMessages() {
        guard !isAtBottom, !isAtTop else { return }

        guard !isTopLoading, !isBottomLoading else { return }

        var anchorMessage: MessageData?

        if firstMessageAppear, !isTopLoading {
            isTopLoading = true
            anchorMessage = loadedMessages.first
        } else if lastMessageAppear, !isBottomLoading {
            isBottomLoading = true
            anchorMessage = loadedMessages.last
        }

        Task {
            defer {
                isTopLoading = false
                isBottomLoading = false
                firstMessageAppear = false
                lastMessageAppear = false
            }

            if let anchorMessage {
                if let loadedMessages = await loadMessages(
                    from: FetchFrom.starting(anchorMessage.createdAt),
                    direction: isTopLoading ? Direction.up : Direction.down,
                    numbers: detailModel.messagesLoadSize
                ) {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true

                    withTransaction(transaction) {
                        self.loadedMessages = loadedMessages
                    }

                    try? await Task.sleep(nanoseconds: UInt64(100_000_000))
                    for _ in 0 ... 10 {
                        withTransaction(transaction) {
                            scrollProxy?.scrollTo(
                                anchorMessage.id,
                                anchor: isTopLoading ? .top : .bottom
                            )
                        }
                        try? await Task.sleep(nanoseconds: UInt64(10_000_000))
                    }
                }
            }
        }
    }

    private func reLoadCurrentMessages() {
        let numbers = loadedMessages.count
        if let startingDate = loadedMessages.first?.createdAt,
           let endingDate = loadedMessages.last?.createdAt {
            Task {
                if let loadedMessages = await loadMessages(
                    from: FetchFrom.starting(startingDate),
                    to: endingDate,
                    numbers: numbers
                ) {
                    self.loadedMessages = loadedMessages
                }
            }
        }
    }

    private func scrollToTopBottom(isToTop: Bool) {
        Task {
            if let loadedMessages = await loadMessages(
                from: isToTop ? FetchFrom.top : FetchFrom.bottom,
                numbers: detailModel.defaultMessages
            ) {
                self.loadedMessages = loadedMessages
                try? await Task.sleep(nanoseconds: UInt64(250_000_000))
                scrollPosition.scrollTo(edge: isToTop ? .top : .bottom)
            }
        }
    }
}
