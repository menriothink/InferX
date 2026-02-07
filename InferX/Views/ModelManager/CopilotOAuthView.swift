//
//  CopilotOAuthView.swift
//  InferX
//
//  GitHub Copilot OAuth login view using Device Flow
//  Each ModelAPI has its own independent authentication
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct CopilotOAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    /// The API ID for which we are authenticating
    let apiId: UUID
    
    @State private var authState: AuthState = .idle
    @State private var deviceCodeResponse: CopilotService.DeviceCodeResponse?
    @State private var errorMessage: String = ""
    @State private var showCopiedAlert = false
    
    var onAuthenticated: (() -> Void)?
    
    enum AuthState {
        case idle
        case requestingDeviceCode
        case waitingForAuthorization
        case polling
        case success
        case error
    }
    
    var body: some View {
        VStack(spacing: 24) {
            headerView
            
            switch authState {
            case .idle:
                idleView
            case .requestingDeviceCode:
                loadingView(message: "Requesting authorization...")
            case .waitingForAuthorization, .polling:
                authorizationView
            case .success:
                successView
            case .error:
                errorView
            }
            
            Spacer()
            
            footerButtons
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 420, height: 480)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("GitHub Copilot")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Sign in to access GitHub Copilot models")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Idle View
    
    private var idleView: some View {
        VStack(spacing: 20) {
            Text("Connect your GitHub account to use Copilot models in InferX.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                startDeviceFlow()
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Sign in with GitHub")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Loading View
    
    private func loadingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Authorization View
    
    private var authorizationView: some View {
        VStack(spacing: 20) {
            if let response = deviceCodeResponse {
                VStack(spacing: 12) {
                    Text("1. Copy this code:")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Text(response.userCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                        
                        Button {
                            copyToClipboard(response.userCode)
                        } label: {
                            Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.title2)
                                .foregroundColor(showCopiedAlert ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                VStack(spacing: 12) {
                    Text("2. Open GitHub and paste the code:")
                        .font(.headline)
                    
                    Button {
                        openVerificationURL(response.verificationUri)
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open GitHub")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 60)
                    
                    Text(response.verificationUri)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if authState == .polling {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Waiting for authorization...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Successfully authenticated!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You can now use GitHub Copilot models.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Authentication Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                authState = .idle
                errorMessage = ""
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Footer
    
    private var footerButtons: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Spacer()
            
            if authState == .success {
                Button("Done") {
                    onAuthenticated?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func startDeviceFlow() {
        authState = .requestingDeviceCode
        
        print("[CopilotOAuthView] Starting device flow for apiId: \(apiId.uuidString)")
        
        Task {
            do {
                let response = try await CopilotService.shared.startDeviceFlow()
                await MainActor.run {
                    deviceCodeResponse = response
                    authState = .waitingForAuthorization
                }
                
                // Start polling after a brief delay to let user see the code
                try await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    authState = .polling
                }
                
                // Poll for access token with API ID
                print("[CopilotOAuthView] Polling for access token with apiId: \(apiId.uuidString)")
                let _ = try await CopilotService.shared.pollForAccessToken(
                    deviceCode: response.deviceCode,
                    interval: response.interval,
                    apiId: apiId
                )
                
                print("[CopilotOAuthView] Authentication successful for apiId: \(apiId.uuidString)")
                
                await MainActor.run {
                    authState = .success
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    authState = .error
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        
        withAnimation {
            showCopiedAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }
    
    private func openVerificationURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Copilot Auth Status View

struct CopilotAuthStatusView: View {
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    /// The API ID for which we are showing auth status
    let apiId: UUID
    
    @State private var isAuthenticated = false
    @State private var showOAuthSheet = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isAuthenticated ? "checkmark.shield.fill" : "shield.slash")
                    .foregroundColor(isAuthenticated ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("GitHub Copilot")
                        .font(.headline)
                    Text(isAuthenticated ? "Authenticated" : "Not signed in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isAuthenticated {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Text("Sign Out")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showOAuthSheet = true
                    } label: {
                        Text("Sign In")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .onAppear {
            checkAuthStatus()
        }
        .sheet(isPresented: $showOAuthSheet) {
            CopilotOAuthView(apiId: apiId) {
                checkAuthStatus()
            }
            .environment(\.locale, locale)
            .environment(\.layoutDirection, layoutDirection)
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await CopilotService.shared.logout(apiId: apiId)
                    await MainActor.run {
                        checkAuthStatus()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to sign out of GitHub Copilot?")
        }
    }
    
    private func checkAuthStatus() {
        print("[CopilotAuthStatusView] Checking auth status for apiId: \(apiId.uuidString)")
        Task {
            let authenticated = await CopilotService.shared.isAuthenticated(apiId: apiId)
            print("[CopilotAuthStatusView] Auth status for apiId \(apiId.uuidString): \(authenticated)")
            await MainActor.run {
                isAuthenticated = authenticated
            }
        }
    }
}

#Preview {
    CopilotOAuthView(apiId: UUID())
}
