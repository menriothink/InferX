//
//  SettingsView.swift
//  InferX
//
//  Created by mingdw on 2025/4/5.
//

import SwiftUI
import Defaults

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Default(.appColorScheme) var appColorScheme
    @Default(.language) var language
    @Default(.backgroundColorWhite) var backgroundColorWhite
    @Default(.backgroundColorBlack) var backgroundColorBlack
    @Default(.fontWeightWhite) var fontWeightWhite
    @Default(.fontWeightBlack) var fontWeightBlack
    @Default(.fontSizeWhite) var fontSizeWhite
    @Default(.fontSizeBlack) var fontSizeBlack
    @Default(.fontNameWhite) var fontNameWhite
    @Default(.fontNameBlack) var fontNameBlack
    @Default(.fontColorDataWhite) var fontColorDataWhite
    @Default(.fontColorDataBlack) var fontColorDataBlack
    @Default(.backgroundContentLightRadius) var backgroundContentLightRadius
    @Default(.backgroundContentDarkRadius) var backgroundContentDarkRadius
    @Default(.proxyHost) var proxyHost
    @Default(.proxyPort) var proxyPort
    @Default(.proxyEnable) var proxyEnable
    @Default(.ignorHost) var ignorHost
    @Default(.gpuCacheLimit) var gpuCacheLimit
    @Default(.gpuCacheLimitEnable) var gpuCacheLimitEnable
    @Default(.appleIntelligenceEffect) var appleIntelligenceEffect

    @State private var tempDirectorySize: String = "Calculating..."
    @State private var isClearing: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let imageSize: CGFloat = 25
    private let minFontSize: CGFloat = 10
    private let maxFontSize: CGFloat = 20
    private let sliderTextWidth: CGFloat = 35
    
    private let systemFonts = [FontManager.defaultFont] + FontManager.shared.availableFonts

    private var maxCacheMemoryLimit: Int {
        let memoryInBytes = ProcessInfo.processInfo.physicalMemory
        let systemMemoryInMB = Int(memoryInBytes / (1024 * 1024))
        let cacheMemoryLimit = Int(Double(systemMemoryInMB) * 0.9)
        return cacheMemoryLimit
    }
    
    var body: some View {
        Form {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 15) {
                HStack {
                    Image(systemName: "globe")
                        .frame(width: imageSize, height: imageSize)
                    
                    Picker("Language", selection: $language) {
                        ForEach(Language.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "paintpalette")
                        .frame(width: imageSize, height: imageSize)
                    Picker("Color Mode", selection: $appColorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { mode in
                            Text(mode.rawValue)
                                .tag(mode)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "slider.horizontal.below.sun.max")
                        .frame(width: imageSize, height: imageSize)
                    Spacer()
                    if colorScheme == .dark {
                        Slider(value: $backgroundColorBlack, in: 0...1)
                    } else {
                        Slider(value: $backgroundColorWhite, in: 0...1)
                    }
                    Spacer()
                    if colorScheme == .dark {
                        Text("\(backgroundColorBlack, specifier: "%.2f")")
                            .frame(width: sliderTextWidth)
                    } else {
                        Text("\(backgroundColorWhite, specifier: "%.2f")")
                            .frame(width: sliderTextWidth)
                    }
                }
                
                HStack {
                    Image(systemName: "slider.horizontal.below.sun.max")
                        .frame(width: imageSize, height: imageSize)
                    Spacer()
                    if colorScheme == .dark {
                        Slider(value: $backgroundContentDarkRadius, in: 0...1)
                    } else {
                        Slider(value: $backgroundContentLightRadius, in: 0...1)
                    }
                    Spacer()
                    if colorScheme == .dark {
                        Text("\(backgroundContentDarkRadius, specifier: "%.2f")")
                            .frame(width: sliderTextWidth)
                    } else {
                        Text("\(backgroundContentLightRadius, specifier: "%.2f")")
                            .frame(width: sliderTextWidth)
                    }
                }
                
                let fontName = colorScheme == .dark ? fontNameBlack : fontNameWhite
                let fontSize = colorScheme == .dark ? fontSizeBlack : fontSizeWhite
                let fontWeight = colorScheme == .dark ? fontWeightBlack.actualWeight : fontWeightWhite.actualWeight
                
                HStack {
                    Spacer()
                    Text("Font Preview")
                        .font(font(forName: fontName, size: fontSize, weight: fontWeight))
                        .padding(.vertical, 5)
                        .frame(height: 40)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "textformat")
                        .frame(width: imageSize, height: imageSize)
                    Picker("Font Selection", selection: colorScheme == .dark ? $fontNameBlack : $fontNameWhite) {
                        ForEach(systemFonts) { font in
                            Text(font.displayName)
                                .tag(font.id)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "base.unit")
                        .frame(width: imageSize, height: imageSize)
                    Picker("Font Weight", selection: colorScheme == .dark ? $fontWeightBlack : $fontWeightWhite) {
                        ForEach(FontWeightOption.allCases) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "arrow.trianglehead.left.and.right.righttriangle.left.righttriangle.right")
                        .frame(width: imageSize, height: imageSize)
                    if colorScheme == .dark {
                        Slider(
                            value: Binding(
                                get: { Double(fontSizeBlack) },
                                set: { fontSizeBlack = CGFloat(Int($0)) }
                            ), in: minFontSize ... maxFontSize
                        )
                    } else {
                        Slider(
                            value: Binding(
                                get: { Double(fontSizeWhite) },
                                set: { fontSizeWhite = CGFloat(Int($0)) }
                            ), in: minFontSize ... maxFontSize
                        )
                    }
                    Text("\(Int(colorScheme == .dark ? fontSizeBlack : fontSizeWhite))")
                        .frame(width: sliderTextWidth)
                }
                
                Divider()
                
                HStack {
                    Text("Proxy Settings")
                    Spacer()
                    Toggle("", isOn: $proxyEnable)
                        .toggleStyle(.switch)
                }
                
                VStack(alignment: .leading) {
                    LabeledTextField(
                        label: "Server Address",
                        placeholder: "e.g: 192.168.1.1",
                        commit: setProxy,
                        text: $proxyHost
                    )
                    
                    LabeledTextField(
                        label: "Port Number",
                        placeholder: "e.g: 9090",
                        commit: setProxy,
                        text: $proxyPort
                    )
                    
                    LabeledTextField(
                        label: "Do not use proxy URLs",
                        placeholder: "e.g: localhost, 127.0.0.1",
                        commit: setProxy,
                        text: $ignorHost
                    )
                }
                .font(.caption)
                .disabled(!proxyEnable)
                
                Divider()
                
                VStack {
                    HStack {
                        Text("Model Memory Size Limits")
                            .font(.system(size: 12))
                        Spacer()
                        Toggle("", isOn: $gpuCacheLimitEnable)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .frame(alignment: .trailing)
                    }
                    
                    HStack {
                        Image(systemName: "externaldrive.badge.timemachine")
                            .frame(width: imageSize, height: imageSize)
                        Spacer()
                        Slider(
                            value: $gpuCacheLimit,
                            in: 1024 ... Double(maxCacheMemoryLimit)
                        )
                        Spacer()
                        
                        Text("\(gpuCacheLimit, specifier: "%.0f") MB")
                            .frame(width: sliderTextWidth + 50, alignment: .trailing)
                            .font(.system(size: 12))
                    }
                    .disabled(!gpuCacheLimitEnable)
                }
                .help("When loading a local model, the memory limit setting.")
                
                Divider()
                
                HStack {
                    Text("Apple Intelligence Effect")
                        .font(.system(size: 12))
                    Spacer()
                    Toggle("", isOn: $appleIntelligenceEffect)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .frame(alignment: .trailing)
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Cache Cleanup")
                        .padding(.bottom, 10)
                    
                    HStack {
                        Text("Temporary File Cache")
                        Spacer()
                        Text(tempDirectorySize)
                            .foregroundColor(.secondary)
                        Button(action: clearTempDirectory) {
                            if isClearing {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Cleaning...")
                                }
                            } else {
                                Image(systemName: "trash")
                                    .renderingMode(.original)
                            }
                        }
                        .disabled(isClearing)
                        .alert(isPresented: $showAlert) {
                            Alert(title: Text("Operation Completed"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                }
                
                Spacer()
            }
        }
        .padding(.top, 40)
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 20)
        .labelsHidden()
        .font(.title3)
        .onChange(of: proxyEnable) {
            setProxy()
        }
        .onAppear {
            calculateTempDirectorySize()
        }
    }

    private var foregroundColor: Color {
        return colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: Color {
        return colorScheme == .dark ? .black : .white
    }
    
    private func font(forName name: String, size: CGFloat, weight: Font.Weight) -> Font {
        if name == "System Font" {
            return .system(size: size, weight: weight)
        } else {
            return .custom(name, size: size).weight(weight)
        }
    }
    
    private func setProxy() {
        Task {
            await OKHTTPClient.shared.setIgnorHost(ignorHost: self.ignorHost)
            if proxyEnable {
                await OKHTTPClient.shared.setProxy(
                    proxyHost: self.proxyHost,
                    proxyPort: UInt32(self.proxyPort)
                )
            } else {
                await OKHTTPClient.shared.setProxy()
            }
        }
    }
    
    private func calculateTempDirectorySize() {
        Task(priority: .userInitiated) {
            let fileManager = FileManager.default
            let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            
            guard let enumerator = fileManager.enumerator(at: tempDirectoryURL, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
                await MainActor.run {
                    self.tempDirectorySize = "Error"
                }
                return
            }
            
            let allFileURLs = enumerator.allObjects.compactMap { $0 as? URL }
            
            var totalSize: Int64 = 0
            
            for fileURL in allFileURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            let formattedSize = FileSizeFormatter.string(from: totalSize)
            await MainActor.run {
                self.tempDirectorySize = formattedSize
            }
        }
    }
        
    private func clearTempDirectory() {
        isClearing = true
        Task(priority: .userInitiated) {
            let fileManager = FileManager.default
            let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            
            var success = true
            var errorMessage = ""

            do {
                let contents = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil, options: [])
                for itemURL in contents {
                    try fileManager.removeItem(at: itemURL)
                }
            } catch {
                success = false
                errorMessage = error.localizedDescription
                print("⚠️ Could not clean temp directory: \(errorMessage)")
            }
            
            await MainActor.run {
                self.alertMessage = success ? "Temporary files have been successfully cleaned." : "Cleanup failed: \(errorMessage)"
                self.showAlert = true
                self.isClearing = false
                calculateTempDirectorySize()
            }
        }
    }
}

struct LabeledTextField: View {
    let label: String
    let placeholder: String
    let commit: () -> Void
    @Binding var text: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(label):")
                .frame(width: 120, alignment: .leading)
            Spacer()
            TextField(placeholder, text: $text, onCommit: commit)
                .textFieldStyle(.roundedBorder)
        }
    }
}

