import SwiftUI
import WebKit
import Foundation
import SwiftSoup
import OSLog

private let isWebViewDebuggingEnabled = false

private let webViewLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "InferX", category: "WebView")

private func logWebView(_ message: String) {
    if isWebViewDebuggingEnabled {
        webViewLogger.log("\(message, privacy: .public)")
    }
}

class CustomWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        self.nextResponder?.scrollWheel(with: event)
    }
}

struct WebView: NSViewRepresentable {
    let htmlString: String
    let fontSize: CGFloat
    let cssWeight: String
    
    let isInteractive: Bool
    
    @Binding var webViewHeight: CGFloat
    
    private var isFullHTMLDocument: Bool {
        let trimmed = htmlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("<!doctype") || trimmed.hasPrefix("<html>")
    }

    private func makeHTMLForSnippet() -> String {
        let headStart = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name='viewport' content='width=device-width, initial-scale=1.0, shrink-to-fit=no'>
        """
        
        let cssStyles = """
        <style>
          :root {
              --bg-color: white;
              --text-color: black;
          }
          @media (prefers-color-scheme: dark) {
              :root {
                  --bg-color: white;
                  --text-color: black;
              }
          }
          body {
            margin: 0;
            padding: 0;
            background-color: transparent;
            overflow: hidden;
            font-family: -apple-system, sans-serif;
            font-size: \(fontSize)px;
            font-weight: \(cssWeight);
            color: var(--text-color);
            height: auto;
          }
          .content-wrapper {
              background-color: var(--bg-color);
              border-radius: 15px;
              padding: 5px 5px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
              height: auto;
          }
        </style>
        """
        
        let bodyContent = """
        </head>
        <body>
            <div class="content-wrapper">
                \(htmlString)
            </div>
        </body>
        </html>
        """
        
        return headStart + cssStyles + bodyContent
    }
    
    private func getFinalHTML() -> String {
        var finalHTML: String
        
        if isFullHTMLDocument {
            finalHTML = htmlString
        } else {
            finalHTML = makeHTMLForSnippet()
        }
        
        let csp = "default-src * 'unsafe-inline' 'unsafe-eval'; script-src * 'unsafe-inline' 'unsafe-eval'; connect-src * 'unsafe-inline'; img-src * data: blob: 'unsafe-inline'; frame-src *; style-src * 'unsafe-inline';"
        let cspMetaTag = "<meta http-equiv='Content-Security-Policy' content=\"\(csp)\">"
        
        if let headRange = finalHTML.range(of: "<head>", options: .caseInsensitive) {
            finalHTML.insert(contentsOf: cspMetaTag, at: headRange.upperBound)
            logWebView("[Swift] Injected CSP meta tag to allow inline scripts.")
        } else {
            logWebView("[Swift] Could not find <head> tag to inject CSP.")
        }
        
        return finalHTML
    }
    
    // MARK: - NSViewRepresentable Conformance
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.setWebView(self)

        let scriptSource: String
        if isInteractive {
            scriptSource = """
                function log(message) {
                    if (\(isWebViewDebuggingEnabled) && window.webkit?.messageHandlers.logHandler) {
                        window.webkit.messageHandlers.logHandler.postMessage(message);
                    }
                }
                log('Running in Interactive Mode.');
                document.addEventListener('DOMContentLoaded', function() {
                    document.body.style.overflow = 'auto';
                });
            """
        } else {
            scriptSource = """
                function log(message) {
                    if (\(isWebViewDebuggingEnabled) && window.webkit?.messageHandlers.logHandler) {
                        window.webkit.messageHandlers.logHandler.postMessage(message);
                    }
                }
                
                const style = document.createElement('style');
                style.textContent = `html, body { min-height: auto !important; height: auto !important; overflow-y: hidden !important; }`;
                if (document.head) {
                    document.head.appendChild(style);
                    log('Injected CSS reset for stability.');
                }

                let lastHeight = 0;

                const postHeight = (source) => {
                    window.requestAnimationFrame(() => {
                        const newHeight = document.documentElement.scrollHeight;
                        if (newHeight !== lastHeight) {
                            lastHeight = newHeight;
                            log(`[${source}] Posting new height = ` + newHeight);
                            window.webkit.messageHandlers.heightHandler.postMessage(newHeight);
                        }
                    });
                };
                
                window.forceHeightRecalculation = () => {
                    log('Received forceHeightRecalculation call from Swift.');
                    postHeight('ForceRecalc');
                };

                const resizeObserver = new ResizeObserver(() => postHeight('ResizeObserver'));
                resizeObserver.observe(document.documentElement);

                document.addEventListener('click', (event) => {
                    if (event.target.tagName.toLowerCase() === 'summary') {
                         log('Click on <summary> detected. Notifying Swift.');
                         window.webkit.messageHandlers.clickHandler.postMessage('collapsible_click');
                    }
                });
                
                postHeight('InitialLoad');
            """
        }

        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        
        if !isInteractive {
            userContentController.add(context.coordinator, name: "heightHandler")
            userContentController.add(context.coordinator, name: "clickHandler")
        }
        userContentController.add(context.coordinator, name: "logHandler")
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        let webView = CustomWKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        
        if let scrollView = webView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            scrollView.hasVerticalScroller = isInteractive
            scrollView.hasHorizontalScroller = false
        }
        
        logWebView("[Swift] makeNSView: Loading HTML. Interactive: \(self.isInteractive)")
        webView.loadHTMLString(getFinalHTML(), baseURL: Bundle.main.resourceURL)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.setWebView(self)
        
        let oldIsInteractive = context.coordinator.lastIsInteractive ?? false
        
        if context.coordinator.lastLoadedHTMLString != htmlString || oldIsInteractive != isInteractive {
            logWebView("[Swift] updateNSView: Reloading. Interactive: \(self.isInteractive)")
            nsView.loadHTMLString(getFinalHTML(), baseURL: Bundle.main.resourceURL)
            if let scrollView = nsView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
                scrollView.hasVerticalScroller = isInteractive
            }
        }
    }
    
    // MARK: - Coordinator
    
    @preconcurrency @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private var parent: WebView?
        weak var webView: WKWebView?
        
        var lastLoadedHTMLString: String?
        var lastIsInteractive: Bool?
        
        private var debounceTask: Task<Void, Never>?

        override init() {
            super.init()
            logWebView("[Coordinator] Initialized.")
        }
        
        func setWebView(_ parent: WebView) {
            self.parent = parent
            self.lastIsInteractive = parent.isInteractive
        }
        
        deinit {
            debounceTask?.cancel()
            logWebView("[Coordinator] Deinitialized.")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let parent = parent, !parent.isInteractive else { return }
            self.lastLoadedHTMLString = parent.htmlString
            logWebView("[Swift] didFinish navigation.")
            self.webView?.evaluateJavaScript("window.forceHeightRecalculation();")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "heightHandler":
                if let height = message.body as? CGFloat {
                    logWebView("[Swift] Received height from JS: \(height)")
                    self.updateHeight(height)
                }
            case "clickHandler":
                logWebView("[Swift] Received click event from JS on a collapsible element.")
                self.handleCollapsibleClick()
            case "logHandler":
                if let logMessage = message.body as? String {
                    logWebView("[JS] \(logMessage)")
                }
            default:
                break
            }
        }
        
        private func handleCollapsibleClick() {
            guard let parent = self.parent, !parent.isInteractive else { return }
            parent.webViewHeight = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.webView?.evaluateJavaScript("window.forceHeightRecalculation();")
            }
        }

        private func updateHeight(_ newHeight: CGFloat) {
            debounceTask?.cancel()
            guard let parent = self.parent, newHeight > 1, abs(parent.webViewHeight - newHeight) > 1 else { return }
            let currentHeight = parent.webViewHeight
            
            debounceTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    logWebView("[Swift] >>> Debounced Update: Setting height from \(currentHeight) to \(newHeight)")
                    self.parent?.webViewHeight = newHeight
                } catch {
                    logWebView("[Swift] Debounce task failed or was cancelled.")
                }
            }
        }
    }
}
