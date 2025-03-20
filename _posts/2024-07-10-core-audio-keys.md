---
layout: post
title:  CoreAudio keys
date:   2024-07-10 19:00:00 +0200
categories: [Audio, Utils]
tags: [how to, macOS, Swift, audio, utils]
author: alexis
description: Collection of functions to retrieve properties of an audio device.
---

This articles references methods to retrieve properties of an audio device. To find out more about a key, you can jump to its definition in Xcode and browse the header file. It's not ideal, but it's there. That's where the description are taken from.

This article will evolve with time.

## General Remarks

The function `checkError(_:)` is used throughout the article. It maps an `OSStatus` to an error when the result code is not 0. You can find its implementation in the [post resources](https://github.com/MoreDocs/moredocs.github.io/blob/main/_posts_resources/Extensions/OSStatus%2BExtensions.swift).
{: .prompt-info }

It's safer to always call [`AudioObjectHasProperty(_:_:)`](https://developer.apple.com/documentation/coreaudio/1422538-audioobjecthasproperty) before fetching a property by its address. It's implicit that the functions in this article always call this API once `AudioObjectPropertyAddress` is filled. It takes the ID of the audio object that is similarly used to get the get or set the property on a device, and the property address.

## Identification
CoreAudio uses two type of identifiers for audio devices. The first one, `AudioDeviceID` is a type alias for `UInt32`.  It is constant during the life cycle of the app, but it's not persisted across launches. It's the identifier that is most often used in the `AudioObjectGetPropertyData(_:_:_:_:_:_:)` function. The other identifier is the UID which is a `CFString` and is persisted across launches. A function to retrieve one from another is provided below.

### Name
**Description**: Contains a human readable name for the category of the given element in the given scope.

```swift
func name(for deviceID: AudioDeviceID) throws -> String {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = kAudioObjectPropertyElementMain

    var name: CFString?
    try withUnsafeMutablePointer(to: &name) { namePointer in
        var nameSize = UInt32.sizeOf(CFString.self)
        try AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &nameSize,
            namePointer
        )
        .checkError("Unable to get device name for device ID \(deviceID)")
    }

    if let name {
        return "\(name)" // forcing copy to avoid leaks in some cases
    } else {
        return ""
    }
}
```

### UID
Retrieve a device UID from its ID.
```swift
func uid(for deviceID: AudioDeviceID) throws -> String {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = kAudioObjectPropertyElementMain

    var uid: CFString = "" as CFString
    try withUnsafeMutablePointer(to: &uid) { mutablePointer in
        let rawPointer = UnsafeMutableRawPointer(mutablePointer)
        var propertySize = UInt32.sizeOf(CFString.self)
        try AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, rawPointer)
            .checkError("Unable to get UID of audio device with id \(deviceID) gor key 'kAudioDevicePropertyDeviceUID'")
    }

    return uid as String
}
```

### UID → ID
Retrieve a device ID from its UID
```swift
func deviceID(for uid: IODevice.UID) throws -> IODevice.ID? {
    var uid = uid as CFString
    let uidSize = UInt32.sizeOf(uid)
    var id: AudioDeviceID = kAudioDeviceUnknown
    let idSize = UInt32.sizeOf(id)

    try withUnsafeMutablePointer(to: &uid) { uidMutablePointer in
        try withUnsafeMutablePointer(to: &id) { idMutablePointer in
            var translation = AudioValueTranslation(
                mInputData: uidMutablePointer,
                mInputDataSize: uidSize,
                mOutputData: idMutablePointer,
                mOutputDataSize: idSize
            )
            var translationSize: UInt32 = .sizeOf(translation)

            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDeviceForUID,
                mScope: AudioScope.global.key,
                mElement: kAudioObjectPropertyElementMain
            )

            try AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &translationSize,
                &translation
            )
            .checkError("Unable to get translation for key 'kAudioObjectSystemObject'")
        }
    }

    guard id != kAudioDeviceUnknown else { return nil }
    return id
}
```

## Listing
List IDs of available audio devices.

```swift
var deviceIDs: [AudioDeviceID] {
    get throws {
        let objectID = AudioObjectID(kAudioObjectSystemObject)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices
            mScope: kAudioObjectPropertyScopeGlobal
            mElement: kAudioObjectPropertyElementMain
        )

        var count: UInt32 = 0
        try AudioObjectGetPropertyDataSize(
            objectID,
            &propertyAddress,
            0,
            nil,
            &count
        )
        .checkError("AudioObjectGetPropertyDataSize failed")

        var ids: [AudioObjectID] = Array(repeating: 0, count: Int(count))
        try AudioObjectGetPropertyData(
            objectID,
            &propertyAddress,
            0,
            nil,
            &count,
            &ids
        )
        .checkError("AudioObjectGetPropertyData failed")

        return ids
    }
}
```

## Channels
### Count
Get the number of channels of an audio device for the provided scope.
```swift
func channelsCount(
    for deviceID: AudioDeviceID, 
    inScope scope: AudioObjectPropertyScope
) throws -> AVAudioChannelCount {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
    propertyAddress.mScope = scope
    propertyAddress.mElement = kAudioObjectPropertyElementMain

    var propertySize: UInt32 = 0
    try AudioObjectGetPropertyDataSize(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &propertySize
    )
    .checkError("AudioObjectGetPropertyDataSize failed")

    let bufferListRawPointer = UnsafeMutableRawPointer.allocate(
        byteCount: Int(propertySize), 
        alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer {
        bufferListRawPointer.deallocate()
    }

    try AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &propertySize,
        bufferListRawPointer
    )
    .checkError("AudioObjectGetPropertyData failed")

    let bufferListPointer = bufferListRawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
    // binding memory since coming from C but `assumingMemoryBound(to:)` is also ok.
    // It seems to be only semantic as of today: https://forums.swift.org/t/what-is-binding-memory/4418/6

    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
    var outputChannels: UInt32 = 0
    for buffer in bufferList {
        outputChannels += buffer.mNumberChannels
    }
    return outputChannels
}
```

### Preferred stereo output
Get the preferred output stereo channels.

**Description**: An array of two `UInt32`, the first for the left channel, the second for the right channel, that indicate the channel numbers to use for stereo IO on the device. The value of this property can be different for input and output and there are no restrictions on the channel numbers that can be used.

```swift
func outputPreferredStereoChannels(for deviceID: AudioDeviceID) throws -> [AVAudioChannelCount] {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyPreferredChannelsForStereo,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var channels: [AVAudioChannelCount] = [0, 0]
    var size = UInt32.sizeOf(channels)
    try AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &size,
        &channels
    )
    .checkError("Unable got get value for key 'kAudioDevicePropertyPreferredChannelsForStereo' on device")
    
    return channels
}
```

Set the output preferred stereo channels.

```swift
func setOutputPreferredStereoChannels(
    of deviceID: AudioDeviceID,
    left: AVAudioChannelCount, 
    right: AVAudioChannelCount
) throws {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyPreferredChannelsForStereo,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var channels = [left, right]
    try AudioObjectSetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        .sizeOf(channels),
        &channels
    )
    .checkError("Unable to set the key 'kAudioDevicePropertyPreferredChannelsForStereo' on device with value \(channels)")
}
```


## Transport
### Type
**Description**: Indicates how the AudioDevice is connected to the CPU.

**Examples**: HDMI, USB, PCI...

```swift
func transportType(for deviceID: AudioDeviceID) throws -> UInt32 {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioDevicePropertyTransportType
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = kAudioObjectPropertyElementMain
    
    var valueSize = UInt32(MemoryLayout<UInt32>.size)
    var rawValue: UInt32 = 0
    try? AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &valueSize,
        &rawValue
    )
    .checkError("Unable to get '\(key)' for object with ID \(objectID)")
    
    return rawValue
}
```

> Compare the returned value to the transport type keys with the prefix `kAudioDeviceTransportType` to identify the port type.
{: .prompt-tip}

## Sample Rate
### Actual
```swift
func actualSampleRate(forObject objectID: AudioObjectID) throws -> Double {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioDevicePropertyActualSampleRate
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = kAudioObjectPropertyElementMain

    var valueSize = UInt32(MemoryLayout<Double>.size)
    var value: Double = 0
    try? AudioObjectGetPropertyData(
        objectID,
        &propertyAddress,
        0,
        nil,
        &valueSize,
        &value
    )
    .checkError("Unable to get '\(key)' for object with ID \(objectID)")

    return value
}
```

### Available
```swift
func availableSampleRates(forObject objectID) throws -> [AudioValueRange] {
    var sampleRates: [AudioValueRange] = Array(
        repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), 
        count: 10
    )
    var size = UInt32.sizeOf(sampleRates)
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    try AudioObjectGetPropertyData(
        id,
        &propertyAddress,
        0,
        nil,
        &size,
        &sampleRates
    )
    .checkError("Unable to get 'kAudioDevicePropertyAvailableNominalSampleRates'")
    
    return sampleRates.filter { $0.mMinimum != 0 || $0.mMaximum != 0 }
}
```
`10` is an arbitrary value that is enough I believe to get all available sample rates. Only the sample rates with at least a minimum or a maximum value different from 0 are considered.

## Aggregate
Those keys that are used on aggregate devices.

### Active devices
**Description**: An array of AudioObjectIDs for all the active sub-devices in the aggregate device.

```swift
func activeDevices(in deviceID: AudioDeviceID) throws -> [AudioDeviceID] {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioAggregateDevicePropertyActiveSubDeviceList
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = kAudioObjectPropertyElementMain
    
    var count: UInt32 = 0
    try AudioObjectGetPropertyDataSize(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &count
    )
    .checkError("AudioObjectGetPropertyDataSize failed")
    
    var ids: [AudioObjectID] = Array(repeating: 0, count: Int(count))
    try AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &count,
        &ids
    )
    .checkError("AudioObjectGetPropertyData failed")
    
    return ids
}
```

### All devices
**Description**: The UIDs of all the devices, active or inactive, contained in the AudioAggregateDevice. The order of the items in the array is significant and is used to determine the order of the streams of the AudioAggregateDevice.

```swift
func allDevices(in deviceID: AudioDeviceID) throws -> [String] {
    var propertyAddress = AudioObjectPropertyAddress()
    propertyAddress.mSelector = kAudioAggregateDevicePropertyFullSubDeviceList
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = kAudioObjectPropertyElementMain

    var count: UInt32 = 0
    try AudioObjectGetPropertyDataSize(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &count
    )
    .checkError("AudioObjectGetPropertyDataSize failed")

    var uids = Array(repeating: " " as CFString, count: Int(count)) as CFArray
    try withUnsafeMutablePointer(to: &uids) { mutablePointer in
        try AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &count,
            mutablePointer
        )
        .checkError("Unable to get get full sub devices list of aggregated device with key 'kAudioAggregateDevicePropertyFullSubDeviceList'")
    }

    return uids as! [String]
}
```