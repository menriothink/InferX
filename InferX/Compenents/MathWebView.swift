// MathWebView.swift
// InferX
//
// Created by mingdw on 2025/5/28.
//

import SwiftUI
import WebKit

final class ScrollPassthroughContainerView: NSView {
    override func scrollWheel(with event: NSEvent) {
        var responder: NSResponder? = self.nextResponder
        while let current = responder {
            if let scroll = current as? NSScrollView {
                scroll.scrollWheel(with: event)
                return
            }
            responder = current.nextResponder
        }
        super.scrollWheel(with: event)
    }
}

struct MathWebView: NSViewRepresentable {
    let latexString: String
    let fontSize: CGFloat
    let cssWeight: String
    
    @Binding var webViewHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let container = ScrollPassthroughContainerView()
        let webView = WKWebView()

        if let scrollView = webView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.scrollerStyle = .overlay
        }
        
        let customWebView = CustomWKWebView1()
        customWebView.parentCoordinator = context.coordinator
        
        customWebView.setValue(false, forKey: "drawsBackground")
        customWebView.wantsLayer = true
        customWebView.layer?.backgroundColor = NSColor.clear.cgColor
        customWebView.navigationDelegate = context.coordinator
        customWebView.configuration.userContentController.removeAllScriptMessageHandlers()
        customWebView.configuration.userContentController.add(context.coordinator, name: "heightHandler")

        container.addSubview(customWebView)

        customWebView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customWebView.topAnchor.constraint(equalTo: container.topAnchor),
            customWebView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            customWebView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            customWebView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let webView = nsView.subviews.first(where: { $0 is CustomWKWebView1 }) as? WKWebView {
            let htmlContent = generateHTMLLaTeX(from: latexString)
            if let baseURL = Bundle.main.resourceURL {
                webView.loadHTMLString(htmlContent, baseURL: baseURL)
            } else {
                print("❌ 资源路径获取失败，无法设置 baseURL")
            }
        } else {
            print("❌ 找不到 CustomWKWebView 实例")
        }
    }
    
    private func generateHTMLLaTeX(from latex: String) -> String {
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <link rel="stylesheet" href="katex.min.css">
                <script defer src="katex.min.js"></script>
                <script defer src="auto-render.min.js"></script>
                <script defer src="contrib/ams.min.js"></script>
                <script defer src="contrib/mhchem.min.js"></script>
                <script defer src="contrib/copy-tex.min.js"></script>
                <style>
                    body {
                        margin: 0;
                        padding: 0;
                        background-color: transparent;
                        overflow: hidden; 
                        width: 100%;
                        height: 100%;
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                        font-size: \(fontSize)px;
                        font-weight: \(cssWeight);
                        line-height: normal; 
                        -webkit-font-smoothing: antialiased;
                    }
                    @media (prefers-color-scheme: dark) {
                        body {
                            color: white;
                        }
                    }

                    .katex {
                        font-family: "KaTeX_Main", "Times New Roman", serif;
                        font-weight: \(cssWeight);
                        font-size: \(fontSize*1.1)px; 
                        /*white-space: 3;*/ 
                                            
                        vertical-align: middle;
                        line-height: 3; 
                    }

                    .katex-display {
                        display: block;      
                        overflow-x: auto;    
                        /*text-align: center*/; 
                        padding-top: 0.5em;    
                        padding-bottom: 2.5em;
                        font-family: "KaTeX_Main", "Times New Roman", serif;
                        font-size: \(fontSize*1.1)px
                        font-weight: \(cssWeight);
                        line-height: normal; 
                        vertical-align: middle;
                    }
                    
                    .katex-display > .katex {
                        display: inline-block;
                    }

                    .katex svg path {
                       fill: currentColor;
                    }
                </style>
            </head>
            <body>
                <div id="math-container">\(latex)</div>
                <script>
                    function postHeight() {
                        const mathContainer = document.getElementById('math-container');
                        if (mathContainer) {
                            const calculatedHeight = mathContainer.getBoundingClientRect().height;
                            window.webkit?.messageHandlers?.heightHandler?.postMessage(calculatedHeight);
                        } else {
                            window.webkit?.messageHandlers?.heightHandler?.postMessage(1);
                        }
                    }

                    function renderAndNotify() {
                        if (typeof renderMathInElement === 'function') {
                            try {
                                renderMathInElement(document.getElementById('math-container'), {
                                    delimiters: 
                                    [
                                      {left: "$$", right: "$$", display: true},
                                      {left: "$", right: "$", display: false},
                                      {left: "\\(", right: "\\)", display: false},
                                      {left: "\\[", right: "\\]", display: true}
                                    ],
                                    throwOnError: false
                                });
                            } catch (e) {
                                console.error("KaTeX rendering error:", e);
                            }
                            
                            window.requestAnimationFrame(function() { 
                                window.requestAnimationFrame(function() {
                                    postHeight();
                                });
                            });
                        } else {
                            console.log("KaTeX not ready, retrying...");
                            setTimeout(renderAndNotify, 100);
                        }
                    }

                    if (document.readyState === "loading") {
                        window.addEventListener("DOMContentLoaded", renderAndNotify);
                    } else {
                        renderAndNotify();
                    }
                </script>
            </body>
        </html>
        """
    }
    
    // MARK: - Coordinator for WKWebViewDelegate and JavaScript message handling
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MathWebView

        init(_ parent: MathWebView) {
            self.parent = parent
        }

        // WKNavigationDelegate method
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Webview navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Webview provisional navigation failed: \(error.localizedDescription)")
        }


        // WKScriptMessageHandler method to receive messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let heightValue = message.body as? NSNumber {
                DispatchQueue.main.async {
                    let newHeight = CGFloat(truncating: heightValue)
                    if abs(self.parent.webViewHeight - newHeight) > 1 {
                         self.parent.webViewHeight = max(1, newHeight)
                    } else if newHeight > 0 && self.parent.webViewHeight == 1 && newHeight > 1 {
                        self.parent.webViewHeight = newHeight
                    }
                }
            }
        }
    }
}

class CustomWKWebView1: WKWebView {
    weak var parentCoordinator: MathWebView.Coordinator?

    override func scrollWheel(with event: NSEvent) {
        var responder: NSResponder? = self.nextResponder
        while let current = responder {
            if let scroll = current as? NSScrollView {
                scroll.scrollWheel(with: event)
                return
            }
            responder = current.nextResponder
        }
    }
}

struct SpecialMathView: View {
    let content: String
    let fontSize: CGFloat
    let fontWeight: FontWeightOption
    
    @State var height: CGFloat = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MathWebView(latexString: content,
                        fontSize: fontSize,
                        cssWeight: fontWeight.rawValue,
                        webViewHeight: $height
                )
                .frame(height: height)
        }
    }
}
