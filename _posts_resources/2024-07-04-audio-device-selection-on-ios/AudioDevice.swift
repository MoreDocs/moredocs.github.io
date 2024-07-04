import AVFoundation

// MARK: - AudioDevice

struct AudioDevice {
    let name: String
    let port: AVAudioSession.Port
    let uid: String
    let channelsCount: Int
}

// MARK: - Hashable

extension AudioDevice: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }

    static func ==(lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

// MARK: - Identifiable

extension AudioDevice: Identifiable {

    var id: String { uid }
}

