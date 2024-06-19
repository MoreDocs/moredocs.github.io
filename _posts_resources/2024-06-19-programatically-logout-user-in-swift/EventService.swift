import AppKit

/// Service to shut down, restart, or put the computer to sleep. Also log out the user.
///
/// ### Resources
/// - [Apple doc](https://developer.apple.com/library/archive/qa/qa1134/_index.html)
/// - Already in use in [SplashBuddy](https://github.com/macadmins/SplashBuddy/blob/main/SplashBuddy/Tools/LoginWindow.swift)
enum EventService {}

// MARK: - Logic

extension EventService {

    static func send(event eventType: AppleEventType) throws {

        // target the login window process for the event
        var loginWindowSerialNumber = ProcessSerialNumber(
            highLongOfPSN: 0,
            lowLongOfPSN: UInt32(kSystemProcess)
        )

        var targetDesc = AEAddressDesc()
        var error = OSErr()

        error = AECreateDesc(
            keyProcessSerialNumber,
            &loginWindowSerialNumber,
            MemoryLayout<ProcessSerialNumber>.size,
            &targetDesc
        )

        if error != noErr {
            throw EventError(
                errorDescription: "Unable to create the description of the app. Status: \(error)"
            )
        }

        // create the Apple event
        var event = AppleEvent()
        error = AECreateAppleEvent(
            kCoreEventClass,
            eventType.eventId,
            &targetDesc,
            AEReturnID(kAutoGenerateReturnID),
            AETransactionID(kAnyTransactionID),
            &event
        )

        AEDisposeDesc(&targetDesc)

        if error != noErr {
            throw EventError(
                errorDescription: "Unable to create an Apple Event for the app description. Status:  \(error)"
            )
        }

        // send the event
        var reply = AppleEvent()
        let status = AESendMessage(
            &event,
            &reply,
            AESendMode(kAENoReply),
            1000
        )

        if status != noErr {
            throw EventError(
                errorDescription: "Error while sending the event \(eventType). Status: \(status)"
            )
        }

        AEDisposeDesc(&event)
        AEDisposeDesc(&reply)
    }
}

// MARK: - Models

extension EventService {

    enum AppleEventType: String {
        case shutdownComputer = "Shut down the computer"
        case restartComputer = "Restart the computer"
        case asleepComputer = "Asleep the computer"
        case logoutUser = "Logout the user"

        var eventId: OSType {
            switch self {
            case .shutdownComputer: return kAEShutDown
            case .restartComputer: return kAERestart
            case .putComputerToSleep: return kAESleep
            case .logoutUser: return kAEReallyLogOut
            }
        }
    }
}

extension EventService.AppleEventType: CaseIterable, Identifiable {

    var id: String { rawValue }
}

extension EventService {

    struct EventError: LocalizedError {
        var errorDescription: String?
    }
}
