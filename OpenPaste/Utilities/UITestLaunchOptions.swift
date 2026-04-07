import Foundation

enum UITestLaunchOptions {
    static var values: [String: String] {
        var merged = ProcessInfo.processInfo.environment
        for (key, value) in UserDefaults.standard.dictionaryRepresentation()
        where key.hasPrefix("OPENPASTE_UI_TEST_") {
            if let bool = value as? Bool {
                merged[key] = bool ? "1" : "0"
            } else {
                merged[key] = String(describing: value)
            }
        }
        let arguments = ProcessInfo.processInfo.arguments
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("-OPENPASTE_UI_TEST_") else {
                index += 1
                continue
            }

            let key = String(argument.dropFirst())
            let nextIndex = index + 1
            if nextIndex < arguments.count, !arguments[nextIndex].hasPrefix("-") {
                merged[key] = arguments[nextIndex]
                index += 2
            } else {
                merged[key] = "1"
                index += 1
            }
        }

        return merged
    }

    static func value(for key: String) -> String? {
        values[key]
    }

    static var isEnabled: Bool {
        value(for: "OPENPASTE_UI_TEST_MODE") == "1"
    }
}
