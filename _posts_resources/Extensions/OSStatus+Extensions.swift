import Foundation

// MARK: - Check error

extension OSStatus {

    /// Error mapped from an `OSStatus`.
    public struct StatusError: Error {

        // MARK: Properties

        let status: OSStatus
        let message: String
    }

    /// Check an `OSStatus` to throw a `StatusError` if status is different from `noError`.
    /// - Parameter message: Message of the error to be thrown.
    /// - throws: If status is different from `noError`.
    public func checkError(_ message: String) throws {
        if self == noErr { return }
        throw StatusError(status: self, message: message)
    }
}
