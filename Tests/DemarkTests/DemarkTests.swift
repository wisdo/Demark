import XCTest
@testable import Demark

@MainActor
final class DemarkTests: XCTestCase {
    
    func testBasicHTMLToMarkdownConversion() async throws {
        let demark = Demark()
        let html = "<h1>Test Heading</h1><p>This is a <strong>test</strong> paragraph.</p>"
        
        let markdown = try await demark.convertToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("# Test Heading"))
        XCTAssertTrue(markdown.contains("**test**"))
        XCTAssertTrue(markdown.contains("paragraph"))
    }
    
    func testDemarkOptionsDefaults() {
        let options = DemarkOptions()
        
        XCTAssertEqual(options.headingStyle, .atx)
        XCTAssertEqual(options.bulletListMarker, "-")
        XCTAssertEqual(options.codeBlockStyle, .fenced)
    }
    
    func testCustomDemarkOptions() {
        let options = DemarkOptions(
            headingStyle: .setext,
            bulletListMarker: "*",
            codeBlockStyle: .indented
        )
        
        XCTAssertEqual(options.headingStyle, .setext)
        XCTAssertEqual(options.bulletListMarker, "*")
        XCTAssertEqual(options.codeBlockStyle, .indented)
    }
    
    func testEmptyHTMLInput() async throws {
        let demark = Demark()
        let html = ""
        
        do {
            _ = try await demark.convertToMarkdown(html)
            XCTFail("Expected error for empty input")
        } catch DemarkError.emptyResult {
            // This is expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testListConversion() async throws {
        let demark = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>"
        
        let markdown = try await demark.convertToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("- Item 1"))
        XCTAssertTrue(markdown.contains("- Item 2"))
        XCTAssertTrue(markdown.contains("- Item 3"))
    }
    
    func testCustomBulletMarker() async throws {
        let demark = Demark()
        let options = DemarkOptions(bulletListMarker: "*")
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        
        let markdown = try await demark.convertToMarkdown(html, options: options)
        
        XCTAssertTrue(markdown.contains("* Item 1"))
        XCTAssertTrue(markdown.contains("* Item 2"))
    }
    
    func testCodeBlockConversion() async throws {
        let demark = Demark()
        let html = "<pre><code>console.log('hello');</code></pre>"
        
        let markdown = try await demark.convertToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("```"))
        XCTAssertTrue(markdown.contains("console.log('hello');"))
    }
    
    func testLinkConversion() async throws {
        let demark = Demark()
        let html = "<p>Visit <a href=\"https://example.com\">our website</a> for more info.</p>"
        
        let markdown = try await demark.convertToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("[our website](https://example.com)"))
        XCTAssertTrue(markdown.contains("Visit"))
        XCTAssertTrue(markdown.contains("for more info"))
    }
    
    func testComplexHTMLStructure() async throws {
        let demark = Demark()
        let html = """
        <div>
            <h2>Features</h2>
            <ul>
                <li>Easy to use</li>
                <li>Fast conversion</li>
            </ul>
            <p>Learn more at <a href="https://github.com">GitHub</a>.</p>
        </div>
        """
        
        let markdown = try await demark.convertToMarkdown(html)
        
        XCTAssertTrue(markdown.contains("## Features"))
        XCTAssertTrue(markdown.contains("- Easy to use"))
        XCTAssertTrue(markdown.contains("- Fast conversion"))
        XCTAssertTrue(markdown.contains("[GitHub](https://github.com)"))
    }
}