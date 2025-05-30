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
    private var webView: WKWebView?
    
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
                // Create TurndownService with options
                var turndownService = new TurndownService(\(optionsString));

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

        // Find JavaScript libraries - try different bundle access methods
        let possibleBundles = [
            Bundle.module,
            Bundle.main,
            Bundle(for: TurndownRuntime.self),
        ]

        var turndownPath: String?

        for bundle in possibleBundles {
            if turndownPath == nil {
                turndownPath = bundle.path(forResource: "turndown.min", ofType: "js")
                if turndownPath != nil {
                    logger.info("Found turndown.min.js in bundle: \(bundle.bundleIdentifier ?? "unknown")")
                } else {
                    // Try in Resources subdirectory
                    if let resourcesPath = bundle.path(forResource: "Resources/turndown.min", ofType: "js") {
                        turndownPath = resourcesPath
                        logger.info("Found turndown.min.js in Resources subdirectory")
                    }
                }
            }
            
            if turndownPath != nil {
                break
            }
        }

        guard let turndownPath else {
            logger.error("turndown.min.js not found in any bundle")
            throw DemarkError.libraryNotFound("turndown.min.js")
        }
        
        do {
            // Load a blank page first
            webView.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)

            // Wait for page to load
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Load Turndown library
            logger.info("Loading Turndown from: \(turndownPath)")
            let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
            logger.info("Successfully read Turndown (\(turndownScript.count) characters)")

            _ = try await webView.evaluateJavaScript(turndownScript)
            logger.info("Successfully loaded Turndown JavaScript library")

            // Verify Turndown is available
            let turndownCheck = try await webView.evaluateJavaScript("typeof TurndownService")
            
            guard let turndownResult = turndownCheck as? String, turndownResult == "function" else {
                logger.error("TurndownService was not properly loaded")
                throw DemarkError.libraryLoadingFailed("TurndownService not available")
            }

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