import SwiftUI
import AppKit

/// Lightweight syntax highlighting using regex-based token coloring.
/// Supports common programming language keywords, strings, comments, and numbers.
struct SyntaxHighlightedCode: View {
    let code: String
    let maxLines: Int
    
    init(code: String, maxLines: Int = 3) {
        self.code = code
        self.maxLines = maxLines
    }
    
    var body: some View {
        Text(highlightedText)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(maxLines)
            .textSelection(.enabled)
    }
    
    private var highlightedText: AttributedString {
        let lines = code.components(separatedBy: .newlines)
        let truncated = lines.prefix(maxLines).joined(separator: "\n")
        
        var result = AttributedString(truncated)
        result.font = .system(.caption, design: .monospaced)
        result.foregroundColor = .primary
        
        applyHighlighting(&result, in: truncated)
        return result
    }
    
    private func applyHighlighting(_ attributed: inout AttributedString, in text: String) {
        let rules: [(pattern: String, color: Color)] = [
            // Comments (// and /* */)
            (#"//[^\n]*"#, .gray),
            (#"/\*[\s\S]*?\*/"#, .gray),
            // Strings
            (#""[^"\\]*(?:\\.[^"\\]*)*""#, Color(nsColor: .systemRed)),
            (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, Color(nsColor: .systemRed)),
            // Numbers
            (#"\b\d+\.?\d*\b"#, Color(nsColor: .systemCyan)),
            // Keywords (multi-language)
            (#"\b(func|let|var|class|struct|enum|protocol|import|return|if|else|guard|switch|case|for|while|do|try|catch|throw|async|await|self|Self|true|false|nil|public|private|internal|static|final|override|init|deinit|extension|typealias|where|in|is|as|break|continue|default|defer|repeat|fallthrough|some|any)\b"#, Color(nsColor: .systemPink)),
            // JS/TS/Python/Go/Rust keywords
            (#"\b(function|const|export|from|require|yield|type|interface|implements|extends|abstract|new|delete|typeof|instanceof|void|null|undefined|def|class|lambda|elif|except|finally|pass|raise|with|print|fn|pub|mut|impl|mod|crate|use|match|loop|move|ref|trait|unsafe)\b"#, Color(nsColor: .systemPink)),
            // Types
            (#"\b(String|Int|Double|Float|Bool|Data|Date|URL|Array|Dictionary|Set|Optional|Result|Error|Any|AnyObject|UUID|NSImage|NSView|View|some)\b"#, Color(nsColor: .systemTeal)),
            // Decorators / attributes
            (#"@\w+"#, Color(nsColor: .systemOrange)),
        ]
        
        for (pattern, color) in rules {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            
            for match in matches {
                guard let range = Range(match.range, in: text),
                      let attrRange = Range(range, in: attributed) else { continue }
                attributed[attrRange].foregroundColor = color
            }
        }
    }
}

// MARK: - Language Detection

enum CodeLanguage: String, Sendable {
    case swift, javascript, typescript, python, go, rust, java, kotlin, ruby, html, css, json, yaml, shell, sql, unknown
    
    static func detect(from content: String) -> CodeLanguage {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.contains("import SwiftUI") || trimmed.contains("import Foundation") || trimmed.contains("@Observable") { return .swift }
        if trimmed.contains("import React") || trimmed.contains("require(") || trimmed.contains("=> {") { return .javascript }
        if trimmed.contains(": string") || trimmed.contains("interface ") || trimmed.contains("<T>") { return .typescript }
        if trimmed.contains("def ") || trimmed.contains("import ") && trimmed.contains("print(") { return .python }
        if trimmed.contains("package main") || trimmed.contains("func main()") || trimmed.contains(":= ") { return .go }
        if trimmed.contains("fn main") || trimmed.contains("let mut") || trimmed.contains("impl ") { return .rust }
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") && trimmed.contains(":") { return .json }
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.contains("<html") { return .html }
        if trimmed.hasPrefix("---") || (trimmed.contains(": ") && !trimmed.contains(";")) { return .yaml }
        if trimmed.hasPrefix("#!") || trimmed.contains("#!/bin") { return .shell }
        if trimmed.uppercased().contains("SELECT ") || trimmed.uppercased().contains("INSERT ") { return .sql }
        
        return .unknown
    }
}
