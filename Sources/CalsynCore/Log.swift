import Foundation

public enum LogLevel: String, Sendable {
    case info = "INFO"
    case error = "ERROR"
}

public enum LogFormatter {
    // Builds one logfmt line: time, level and msg first, then the fields in the given order.
    // A value is quoted when it is empty or holds a space, `=`, `"` or a control character;
    // inside quotes, backslash, quote, newline, carriage return and tab are escaped.
    public static func line(
        level: LogLevel,
        msg: String,
        fields: KeyValuePairs<String, Any> = [:],
        time: Date = Date()
    ) -> String {
        var parts = [
            "time=\(timestamp(time))",
            "level=\(level.rawValue)",
            "msg=\(quote(msg))",
        ]
        for (key, value) in fields {
            parts.append("\(key)=\(quote(String(describing: value)))")
        }
        return parts.joined(separator: " ")
    }

    public static func quote(_ value: String) -> String {
        let needsQuotes = value.isEmpty || value.unicodeScalars.contains { scalar in
            scalar == " " || scalar == "=" || scalar == "\"" || scalar == "\\"
                || CharacterSet.controlCharacters.contains(scalar)
        }
        guard needsQuotes else {
            return value
        }
        var escaped = ""
        for character in value {
            switch character {
            case "\\": escaped.append("\\\\")
            case "\"": escaped.append("\\\"")
            case "\n": escaped.append("\\n")
            case "\r": escaped.append("\\r")
            case "\t": escaped.append("\\t")
            default: escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    private static func timestamp(_ time: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter.string(from: time)
    }
}

public enum Log {
    public static func info(_ msg: String, _ fields: KeyValuePairs<String, Any> = [:]) {
        write(LogFormatter.line(level: .info, msg: msg, fields: fields))
    }

    public static func error(_ msg: String, _ fields: KeyValuePairs<String, Any> = [:]) {
        write(LogFormatter.line(level: .error, msg: msg, fields: fields))
    }

    private static func write(_ line: String) {
        FileHandle.standardOutput.write(Data("\(line)\n".utf8))
    }
}
