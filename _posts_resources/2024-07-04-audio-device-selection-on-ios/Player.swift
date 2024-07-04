import AVFoundation

// MARK: - Player

final class Player {

    // MARK: Properties

    let session = AVAudioSession.sharedInstance()
    var devices: [AudioDevice] = []
    let engine = AVAudioEngine()

    /// Might get a default stub value when working with a SwiftUI Picker
    var selectedDevice: AudioDevice? {
        didSet {
            guard let selectedDevice else { return }
            setupChanelMappingForAudioDevice(selectedDevice)
        }
    }

    // MARK: Init

    nonisolated init() {}
}

// MARK: - Setup

extension Player {

    func setup() throws {
        try session.setCategory(.multiRoute)
        try session.setActive(true)

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)

        retrieveAudioDevices()
        if let firstDevice = devices.first {
            selectedDevice = firstDevice
            setupChanelMappingForAudioDevice(firstDevice)
        }

        try engine.start()

        guard
            let fileURL = Bundle.main.url(forResource: "song", withExtension: "mp3"),
            let file = try? AVAudioFile(forReading: fileURL)
        else { return }

        playerNode.scheduleFile(file, at: nil)
        playerNode.play()
    }

    private func retrieveAudioDevices() {
        devices.removeAll()
        for portDescription in session.currentRoute.outputs {
            let device = AudioDevice(
                name: portDescription.portName,
                port: portDescription.portType,
                uid: portDescription.uid,
                channelsCount: portDescription.channels?.count ?? 0
            )
            devices.append(device)
        }
    }
}

// MARK: - Channel Mapping

extension Player {

    private func setupChanelMappingForAudioDevice(_ selectedDevice: AudioDevice) {
        var channelsStart = 0
        for device in devices {
            if device == selectedDevice {
                break
            } else {
                channelsStart += device.channelsCount
            }
        }

        var channelMap = Array(repeating: -1, count: Int(engine.outputNode.outputFormat(forBus: 0).channelCount))
        channelMap[channelsStart] = 0
        channelMap[channelsStart + 1] = 1
        engine.outputNode.auAudioUnit.channelMap = channelMap as [NSNumber]
    }
}
