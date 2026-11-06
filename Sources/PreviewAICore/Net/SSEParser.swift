import Foundation

public struct SSEEvent: Equatable, Sendable {
    public var event: String
    public var data: String
}

/// Incremental Server-Sent Events parser. Feed it bytes as they arrive (split anywhere); it
/// returns complete events. Handles CRLF, multi-line `data:`, comments, and missing `event:`.
public struct SSEParser: Sendable {
    private var line: [UInt8] = []
    private var event = ""
    private var data: [String] = []
    /// The previous byte was a bare CR, so a following LF belongs to the same line ending.
    private var afterCR = false

    public init() {}

    public mutating func feed<S: Sequence>(_ bytes: S) -> [SSEEvent] where S.Element == UInt8 {
        var events: [SSEEvent] = []
        // Lines end with LF, CRLF, or a bare CR (all allowed by the SSE spec).
        for byte in bytes {
            if byte == UInt8(ascii: "\n") && afterCR {
                afterCR = false
                continue
            }
            afterCR = false
            if byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") {
                afterCR = byte == UInt8(ascii: "\r")
                if let event = process(String(decoding: line, as: UTF8.self)) { events.append(event) }
                line.removeAll(keepingCapacity: true)
            } else {
                line.append(byte)
            }
        }
        return events
    }

    /// Flushes a final event if the stream ended without a trailing blank line.
    public mutating func finish() -> [SSEEvent] {
        var events = feed([UInt8(ascii: "\n")])
        if let event = process("") { events.append(event) }
        return events
    }

    private mutating func process(_ line: String) -> SSEEvent? {
        if line.isEmpty {
            defer { event = ""; data = [] }
            guard !data.isEmpty else { return nil }
            return SSEEvent(event: event.isEmpty ? "message" : event, data: data.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil }  // comment / keep-alive
        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.first == " " { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }
        switch field {
        case "event": event = String(value)
        case "data": data.append(String(value))
        default: break
        }
        return nil
    }
}
