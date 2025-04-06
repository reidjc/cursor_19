import Foundation

/**
 * LogManager - A simple singleton class to handle in-memory logging.
 *
 * Provides methods to log messages, retrieve all logs as a single string,
 * and clear the stored logs. Includes timestamps and basic thread safety.
 */
class LogManager {
    static let shared = LogManager() // Singleton instance

    private var logMessages: [String] = []
    private let dateFormatter = ISO8601DateFormatter()
    private let logQueue = DispatchQueue(label: "com.yourapp.logmanager.queue") // For thread safety
    private let maxLogEntries = 2000 // Limit memory usage

    private init() {
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        log("LogManager initialized.") // Log initialization
    }

    /**
     * Adds a timestamped log entry to the in-memory store and prints to console.
     * Trims old logs if the maximum number of entries is exceeded.
     * - Parameter message: The string message to log.
     */
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        // Handle potential multi-line messages neatly
        let lines = message.split(separator: "\\n")
        let timestampedLines = lines.map { "[\(timestamp)] \($0)" }
        let logEntry = timestampedLines.joined(separator: "\\n")

        // Append to internal storage (thread-safe) and trim if needed
        logQueue.async {
            self.logMessages.append(logEntry)
            // Trim old logs if exceeding limit
            if self.logMessages.count > self.maxLogEntries {
                self.logMessages.removeFirst(self.logMessages.count - self.maxLogEntries)
                // Optionally log that trimming occurred, but be careful not to spam
                // if !self.logMessages.first!.contains("Log trimmed") {
                //    self.logMessages.insert("[...] Log trimmed [...]", at: 0)
                // }
            }
        }

        // Also print to console for development convenience
        print(logEntry)
    }

    /**
     * Retrieves all stored log messages as a single newline-separated string.
     * Thread-safe access to the log store.
     * - Returns: A string containing all log entries.
     */
    func getLogsAsString() -> String {
        // Access storage thread-safely
        logQueue.sync {
            return logMessages.joined(separator: "\\n")
        }
    }

    /**
     * Clears all log messages from the in-memory store.
     * Thread-safe operation.
     */
    func clearLogs() {
        logQueue.async {
            self.logMessages.removeAll()
        }
        log("Logs cleared.") // Log the clearing action
    }
} 