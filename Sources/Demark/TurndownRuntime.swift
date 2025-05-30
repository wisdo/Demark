import Foundation
import WebKit
import os.log

/// WKWebView-based HTML to Markdown conversion using Turndown.js
///
/// This implementation uses WKWebView for proper DOM support:
/// - Real browser DOM environment
/// - Native HTML parsing
/// - Turndown.js with full DOM support
/// - Main thread execution required for WKWebView
/// - Cross-platform support (iOS, macOS, tvOS, watchOS, visionOS)
@MainActor
final class TurndownRuntime: Sendable {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.demark", category: "turndown")
    private var isInitialized = false
    // Strong reference to prevent garbage collection
    private var webView: WKWebView?
    
    // MARK: - Lifecycle
    
    deinit {
        logger.info("TurndownRuntime being deallocated")
    }
    
    // MARK: - Public Methods
    
    /// Convert HTML to Markdown using Turndown.js
    func convert(_ html: String, options: DemarkOptions) async throws -> String {
        // Ensure initialization
        if !isInitialized {
            logger.info("WKWebView environment not initialized, initializing now...")
            try await initializeJavaScriptEnvironment()
        }

        guard isInitialized else {
            logger.error("JavaScript environment failed to initialize")
            throw DemarkError.jsEnvironmentInitializationFailed
        }

        guard let webView else {
            logger.error("WKWebView not available")
            throw DemarkError.webViewInitializationFailed
        }
        
        // Check if TurndownService is still available (handles process termination)
        do {
            let turndownCheck = try await webView.evaluateJavaScript("typeof TurndownService")
            if let result = turndownCheck as? String, result != "function" {
                logger.warning("TurndownService not available (type: \(result)), reinitializing...")
                isInitialized = false
                try await initializeJavaScriptEnvironment()
                
                guard isInitialized, let _ = self.webView else {
                    throw DemarkError.jsEnvironmentInitializationFailed
                }
            }
        } catch {
            logger.warning("Failed to check TurndownService availability: \(error), reinitializing...")
            isInitialized = false
            try await initializeJavaScriptEnvironment()
            
            guard isInitialized, let _ = self.webView else {
                throw DemarkError.jsEnvironmentInitializationFailed
            }
        }

        // Build Turndown options
        let optionsDict: [String: Any] = [
            "headingStyle": options.headingStyle.rawValue,
            "hr": "---",
            "bulletListMarker": options.bulletListMarker,
            "codeBlockStyle": options.codeBlockStyle.rawValue,
            "fence": "```",
            "emDelimiter": "_",
            "strongDelimiter": "**",
            "linkStyle": "inlined",
            "linkReferenceStyle": "full",
        ]

        // Escape the HTML for JavaScript
        let escapedHTML = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        // Convert options to JSON string
        let optionsData = try JSONSerialization.data(withJSONObject: optionsDict)
        guard let optionsString = String(data: optionsData, encoding: .utf8) else {
            throw DemarkError.invalidInput("Failed to serialize options")
        }

        // Build JavaScript code with support for skip/ignore tags
        let skipTagsJS = options.skipTags.isEmpty ? "" : """
            \(options.skipTags.map { "turndownService.keep(['\($0)']);" }.joined(separator: "\n"))
        """
        
        let ignoreTagsJSON = try JSONSerialization.data(withJSONObject: options.ignoreTags)
        let ignoreTagsString = String(data: ignoreTagsJSON, encoding: .utf8) ?? "[]"
        let ignoreTagsJS = options.ignoreTags.isEmpty ? "" : """
            turndownService.remove(\(ignoreTagsString));
        """

        let jsCode = """
        (function() {
            try {
                // Find TurndownService constructor
                var TurndownConstructor = null;
                if (typeof TurndownService !== 'undefined') {
                    TurndownConstructor = TurndownService;
                } else if (typeof window.TurndownService !== 'undefined') {
                    TurndownConstructor = window.TurndownService;
                } else {
                    throw new Error('TurndownService is not available');
                }
                
                // Create TurndownService with options
                var turndownService = new TurndownConstructor(\(optionsString));

                // Configure service
                turndownService.keep(['del', 'ins', 'sup', 'sub']);
                turndownService.remove(['script', 'style']);
                
                // Apply custom skip/ignore rules
                \(skipTagsJS)
                \(ignoreTagsJS)

                // Convert HTML to Markdown
                var markdown = turndownService.turndown("\(escapedHTML)");

                // Return result
                return markdown;
            } catch (error) {
                throw new Error('Conversion failed: ' + error.message);
            }
        })();
        """

        logger.debug("Executing Turndown conversion...")

        do {
            let result = try await webView.evaluateJavaScript(jsCode)

            guard let markdown = result as? String else {
                logger.error("JavaScript result is not a string: \(type(of: result))")
                throw DemarkError.conversionFailed
            }

            logger.info("Turndown conversion completed (output length: \(markdown.count))")

            // More nuanced handling of empty results
            if markdown.isEmpty, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logger.debug("Conversion resulted in empty markdown for non-empty HTML input.")
                throw DemarkError.emptyResult
            }

            logger.debug("Conversion successful, returning result")
            return markdown

        } catch {
            logger.error("JavaScript exception during conversion: \(error)")
            throw DemarkError.jsException(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeJavaScriptEnvironment() async throws {
        logger.info("Initializing WKWebView environment for HTML to Markdown conversion")

        // Create WKWebView configuration
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()
        
        // Platform-specific configuration
        #if os(macOS)
        // macOS-specific optimizations
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        #elseif os(iOS) || os(visionOS)
        // iOS/visionOS-specific optimizations
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        #endif

        // Create WKWebView with appropriate frame
        #if os(watchOS) || os(tvOS)
        // For watchOS and tvOS, use minimal frame
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: config)
        #else
        // For iOS, macOS, visionOS
        webView = WKWebView(frame: .zero, configuration: config)
        #endif
        guard webView != nil else {
            logger.error("Failed to create WKWebView")
            throw DemarkError.webViewInitializationFailed
        }
        logger.info("Successfully created WKWebView")

        // Load JavaScript libraries
        try await loadJavaScriptLibraries()
    }

    private func loadJavaScriptLibraries() async throws {
        logger.info("Loading JavaScript libraries into WKWebView")

        guard let webView else {
            throw DemarkError.webViewInitializationFailed
        }

        // Find JavaScript library using helper
        guard let turndownPath = BundleResourceHelper.findJavaScriptResource(
            named: "turndown.min",
            classForBundle: TurndownRuntime.self
        ) else {
            logger.error("turndown.min.js not found in any bundle")
            throw DemarkError.libraryNotFound("turndown.min.js")
        }
        
        logger.info("Found turndown.min.js at: \(turndownPath)")
        
        do {
            // Load a blank page first
            webView.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)

            // Wait for page to load
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Load Turndown library
            logger.info("Loading Turndown from: \(turndownPath)")
            let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
            logger.info("Successfully read Turndown (\(turndownScript.count) characters)")

            // Load the Turndown library directly
            _ = try await webView.evaluateJavaScript(turndownScript)
            logger.info("Successfully loaded Turndown JavaScript library")
            
            // Wait a bit for the script to fully initialize
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Check what's available in the global scope
            let globalCheck = try await webView.evaluateJavaScript("""
                JSON.stringify({
                    hasTurndownService: typeof TurndownService !== 'undefined',
                    hasTurndown: typeof Turndown !== 'undefined',
                    hasWindowTurndownService: typeof window.TurndownService !== 'undefined',
                    hasWindowTurndown: typeof window.Turndown !== 'undefined'
                })
            """)
            
            if let checkResult = globalCheck as? String {
                logger.info("Global scope check: \(checkResult)")
            }
            
            // Since TurndownService is available, we don't need to do anything else
            // The global scope check confirmed it's there

            isInitialized = true
            logger.info("WKWebView runtime ready with Turndown 🎉")

        } catch let error as DemarkError {
            throw error
        } catch {
            logger.error("Failed to load JavaScript libraries: \(error)")
            throw DemarkError.libraryLoadingFailed(error.localizedDescription)
        }
    }
}