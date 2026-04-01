import Foundation
import Testing
@testable import OpenPaste

struct SyntaxHighlightedCodeTests {

    // MARK: - Swift Detection

    @Test func detectSwiftImportSwiftUI() {
        let code = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                Text("Hello")
            }
        }
        """
        #expect(CodeLanguage.detect(from: code) == .swift)
    }

    @Test func detectSwiftImportFoundation() {
        let code = """
        import Foundation
        let x = 42
        """
        #expect(CodeLanguage.detect(from: code) == .swift)
    }

    @Test func detectSwiftObservable() {
        let code = """
        @Observable
        class ViewModel {
            var count = 0
        }
        """
        #expect(CodeLanguage.detect(from: code) == .swift)
    }

    // MARK: - JavaScript Detection

    @Test func detectJavaScriptRequire() {
        let code = """
        const express = require('express');
        const app = express();
        """
        #expect(CodeLanguage.detect(from: code) == .javascript)
    }

    @Test func detectJavaScriptImportReact() {
        let code = """
        import React from 'react';
        const App = () => <div>Hello</div>;
        """
        #expect(CodeLanguage.detect(from: code) == .javascript)
    }

    @Test func detectJavaScriptArrowFunction() {
        let code = """
        const handler = (event) => {
            console.log(event);
        };
        """
        #expect(CodeLanguage.detect(from: code) == .javascript)
    }

    // MARK: - TypeScript Detection

    @Test func detectTypeScriptInterface() {
        let code = """
        interface User {
            name: string;
            age: number;
        }
        """
        #expect(CodeLanguage.detect(from: code) == .typescript)
    }

    @Test func detectTypeScriptStringType() {
        let code = """
        function greet(name: string): void {
            console.log(name);
        }
        """
        #expect(CodeLanguage.detect(from: code) == .typescript)
    }

    // MARK: - Python Detection

    @Test func detectPythonDefAndPrint() {
        let code = """
        import os
        def hello():
            print("Hello, World!")
        """
        #expect(CodeLanguage.detect(from: code) == .python)
    }

    // MARK: - Go Detection

    @Test func detectGoPackageMain() {
        let code = """
        package main

        import "fmt"

        func main() {
            fmt.Println("Hello")
        }
        """
        #expect(CodeLanguage.detect(from: code) == .go)
    }

    @Test func detectGoFuncMain() {
        let code = """
        func main() {
            x := 10
        }
        """
        #expect(CodeLanguage.detect(from: code) == .go)
    }

    @Test func detectGoWalrusOperator() {
        let code = """
        x := getValue()
        y := compute(x)
        """
        #expect(CodeLanguage.detect(from: code) == .go)
    }

    // MARK: - Rust Detection

    @Test func detectRustFnMain() {
        let code = """
        fn main() {
            println!("Hello, world!");
        }
        """
        #expect(CodeLanguage.detect(from: code) == .rust)
    }

    @Test func detectRustLetMut() {
        let code = """
        let mut x = 5;
        x += 1;
        """
        #expect(CodeLanguage.detect(from: code) == .rust)
    }

    @Test func detectRustImpl() {
        let code = """
        impl MyStruct {
            fn new() -> Self { ... }
        }
        """
        #expect(CodeLanguage.detect(from: code) == .rust)
    }

    // MARK: - HTML Detection

    @Test func detectHTMLDoctype() {
        let code = "<!DOCTYPE html><html><body><div>Hello</div></body></html>"
        #expect(CodeLanguage.detect(from: code) == .html)
    }

    @Test func detectHTMLTag() {
        let code = "<html><head><title>Test</title></head></html>"
        #expect(CodeLanguage.detect(from: code) == .html)
    }

    // MARK: - JSON Detection

    @Test func detectJSON() {
        let code = """
        {"name": "test", "version": "1.0"}
        """
        #expect(CodeLanguage.detect(from: code) == .json)
    }

    @Test func detectJSONNested() {
        let code = """
        {"key": {"nested": true}}
        """
        #expect(CodeLanguage.detect(from: code) == .json)
    }

    // MARK: - YAML Detection

    @Test func detectYAMLFrontmatter() {
        let code = """
        ---
        title: My Document
        version: 1.0
        """
        #expect(CodeLanguage.detect(from: code) == .yaml)
    }

    // MARK: - Shell Detection

    @Test func detectShellShebang() {
        let code = "#!/bin/bash\necho 'hello'"
        #expect(CodeLanguage.detect(from: code) == .shell)
    }

    // MARK: - SQL Detection

    @Test func detectSQLSelect() {
        let code = "SELECT * FROM users WHERE id = 1;"
        #expect(CodeLanguage.detect(from: code) == .sql)
    }

    @Test func detectSQLInsert() {
        let code = "INSERT INTO users (name, age) VALUES ('Alice', 30);"
        #expect(CodeLanguage.detect(from: code) == .sql)
    }

    // MARK: - Unknown Detection

    @Test func detectUnknownPlainText() {
        let code = "This is just a plain English sentence with no code."
        #expect(CodeLanguage.detect(from: code) == .unknown)
    }

    @Test func detectUnknownEmptyString() {
        #expect(CodeLanguage.detect(from: "") == .unknown)
    }

    @Test func detectUnknownWhitespaceOnly() {
        #expect(CodeLanguage.detect(from: "   \n\t  ") == .unknown)
    }

    // MARK: - Edge Cases

    @Test func detectFromLeadingWhitespace() {
        let code = """

            import SwiftUI
            struct MyView: View { }
        """
        #expect(CodeLanguage.detect(from: code) == .swift)
    }

    @Test func codeLanguageRawValues() {
        #expect(CodeLanguage.swift.rawValue == "swift")
        #expect(CodeLanguage.javascript.rawValue == "javascript")
        #expect(CodeLanguage.typescript.rawValue == "typescript")
        #expect(CodeLanguage.python.rawValue == "python")
        #expect(CodeLanguage.go.rawValue == "go")
        #expect(CodeLanguage.rust.rawValue == "rust")
        #expect(CodeLanguage.html.rawValue == "html")
        #expect(CodeLanguage.json.rawValue == "json")
        #expect(CodeLanguage.unknown.rawValue == "unknown")
    }
}
