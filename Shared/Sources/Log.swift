import Foundation

/// Tiny logging helper so SDK payloads / events are easy to read in the console
/// and mirror-able into the on-screen text view.
enum Log {

    static var sink: ((String) -> Void)?

    static func line(_ message: String) {
        NSLog("[TPAPTest] %@", message)
        sink?(message)
    }

    static func json(_ tag: String, _ object: Any) {
        let pretty: String
        if JSONSerialization.isValidJSONObject(object),
           let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            pretty = string
        } else {
            pretty = "\(object)"
        }
        NSLog("[TPAPTest] %@\n%@", tag, pretty)
        sink?("\(tag)\n\(pretty)")
    }
}
