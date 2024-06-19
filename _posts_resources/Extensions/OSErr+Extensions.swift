import Foundation

// MARK: - Check error

extension OSErr {

    /// Error mapped from an `OSErr`.
    public struct StatusError: Error {

        // MARK: Properties

        let status: OSErr
        let message: String
    }

    /// Check an `OSErr` to throw a `StatusError` if status is different from `noError`.
    /// - Parameter message: Message of the error to be thrown.
    /// - throws: If status is different from `noErr`.
    public func checkError(_ message: String) throws {
        if self == noErr { return }
        throw StatusError(status: self, message: message)
    }
}
