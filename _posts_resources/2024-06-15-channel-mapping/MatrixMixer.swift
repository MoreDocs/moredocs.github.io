// MARK: Main setup

func attachMatrixMixerAndStartEngine() async throws {
    let matrixMixer = try await matrixMixerNode()
    engine.attach(matrixMixer)
    engine.connect(inputNode, to: matrixMixer, format: inputFormat)
    engine.connect(matrixMixer, to: engine.mainMixerNode, format: inputFormat)

    try engine.start()
    try setupMatrixMixerGains(on: matrixMixer)

    for inputChannel in 0..<inputFormat.channelCount {
        setInputVolume(
            1,
            on: matrixMixer,
            forInputChannel: inputChannel,
            toOutputChannels: [0, 1]
        )
    }
}

// MARK: Instantiate

func matrixMixerNode() async throws -> AVAudioUnit {
    let description = AudioComponentDescription(
        componentType: kAudioUnitType_Mixer,
        componentSubType: kAudioUnitSubType_MatrixMixer,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    return try await .instantiate(with: description)
}

// MARK: Setup gains

func setupMatrixMixerGains(on matrixMixerNode: AVAudioUnit) throws {
    try setGlobalGain(on: matrixMixerNode)
    try setInputGains(on: matrixMixerNode)
    try setOutputGains(on: matrixMixerNode)
}

func setGlobalGain(on matrixMixerNode: AVAudioUnit) throws {
    try setAudioUnitValue(
        avAudioUnit: matrixMixerNode,
        for: kMatrixMixerParam_Volume,
        in: kAudioUnitScope_Global,
        element: 0xFFFF_FFFF,
        to: 1
    )
}

func setInputGains(on matrixMixerNode: AVAudioUnit) throws {
    let inputChannelsCount = matrixMixerNode.inputFormat(forBus: 0).channelCount
    for inputChannelIndex in 0..<inputChannelsCount {
        try setAudioUnitValue(
            avAudioUnit: matrixMixerNode,
            for: kMatrixMixerParam_Volume,
            in: kAudioUnitScope_Input,
            element: inputChannelIndex,
            to: 1
        )
    }
}

func setOutputGains(on matrixMixerNode: AVAudioUnit) throws {
    let outputChannelsCount = matrixMixerNode.outputFormat(forBus: 0).channelCount
    for outputChannelIndex in 0..<outputChannelsCount {
        try setAudioUnitValue(
            avAudioUnit: matrixMixerNode,
            for: kMatrixMixerParam_Volume,
            in: kAudioUnitScope_Output,
            element: outputChannelIndex,
            to: 1
        )
    }
}

// MARK: Cross points

func setInputVolume(
    _ volume: Float,
    on matrixMixerNode: AVAudioUnit,
    forInputChannel inputChannelIndex: AVAudioChannelCount,
    toOutputChannels outputChannelIndexes: Set<AVAudioChannelCount>
) {
    let outputChannelsCount = matrixMixerNode.outputFormat(forBus: 0).channelCount
    for outputChannelIndex in 0..<outputChannelsCount {
        let volume = outputChannelIndexes.contains(outputChannelIndex) ? volume : 0

        let crossPoint = (inputChannelIndex << AVAudioChannelCount(16)) | outputChannelIndex
        try! setAudioUnitValue(
            avAudioUnit: matrixMixerNode,
            for: kMatrixMixerParam_Volume,
            in: kAudioUnitScope_Global,
            element: crossPoint,
            to: volume
        )
    }
}

// MARK: Helpers

func setAudioUnitValue(
    avAudioUnit: AVAudioUnit,
    for parameterID: AudioUnitParameterID,
    in scope: UInt32,
    element: AudioUnitElement = 0,
    to newValue: Float
) throws {
    try AudioUnitSetParameter(
        avAudioUnit.audioUnit,
        parameterID,
        scope,
        element,
        newValue,
        0
    )
    .checkError("Error while calling 'AudioUnitSetParameter'")
}

