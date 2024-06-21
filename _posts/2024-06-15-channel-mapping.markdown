---
layout: post
title:  Channel Mapping
date:   2024-06-15 15:47:23 +0200
categories: [Audio, Routing]
tags: [how to, macOS, iOS, Swift, AVAudioEngine, audio, routing, channel mapping]
author: alexis
mermaid: true
description: How to implement channel mapping with AVAudioEngine
---

Channel mapping is a way of describing how input channels are mapped to output channels. The term "input" here refers to the input of a processing unit. It can be an unit that simply mixes audio like `AVAudioMixerNode`, or one that is used to retrieve audio from input devices such as microphones, MIDI devices and so on - typically the audio unit used in `AVAudioEngine.inputNode`.

## When to use it
Channel mapping is useful in many situations because it allows to fine-grained how a stream from each input channel can be routed to one, several or no output channels. Here are two examples where channel mapping could be used.

#### Duplicate audio
Let’s say for instance that you have a microphone plugged in to a device (or you are using the device built-in microphone). The output is a stereo so it has two channels, and the way `AVAudioEngine` works makes that the input has one channel. By default, channel are mapped with a 1:1 relationship so the audio stream from the input channel (index 0) will be routed to the first output channel (index 0), and the second output channel (index 1) will not receive any audio input. The diagram below summarizes that.

```mermaid
flowchart LR
input0[input 0] --> output0[output 0]
input1[∅] --> output1[output 1]
```
In this case, you might want to route [input 0] to both [output 0] and [output 1] so that the microphone audio is heard in both speakers:

```mermaid
flowchart LR
input0[input 0] --> output0[output 0]
input0[input 0] --> output1[output 1]
```

#### Route stereo to another device
It is quite common to have more than two outputs when playing audio. For instance when an audio interface with four output channels is plugged in, or when using the [`multiRoute`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category/1616484-multiroute) category of `AVAudioSession` with two stereo devices plugged in.
In such a case, being able to send a stereo input stream to the third and fourth channels (respectively [output 2] and [output 3]) might be needed so that the audio stream is heard in the proper device.

```mermaid
flowchart LR
none[∅] --> output0[output 0] -.- device1[1st device]
none[∅] --> output1[output 1] -.- device1[1st device]
input0[input 0] --> output2[output 2] -.- device2[2nd device]
input1[input 1] --> output3[output 3] -.- device2[2nd device]
```

## Using a channel map
The easiest API to operate a channel mapping is the [`channelMap`](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/2143054-channelmap) property of `AUAudioUnit`, which is an Obj-C wrapper around `AudioUnit` from CoreAudio. It can be set on some specific audio nodes in the graph of an `AVAudioEngine`.

> From my experience `channelMap` only works on `AVAudioEngine.outputNode` and `AVAudioPlayerNode`.
{: .prompt-info }

 Setting it on an output node is fairly easy:

```swift
let engine = AVAudioEngine()
engine.outputNode.auAudioUnit.channelMap = [0, 1]
```

This property describes what input channel should be routed to the output channel at the given index. Output channels are associated to the *indexes of the array*, and input channels are the *values in the array*.

Let’s use the second example where input stereo is routed to a second device. The default channel map that is used would be `[0, 1, -1, -1]`.
- 0 at the index 0 means that [output 0] should receive the audio stream from [input 0].
- Similarly, [output 1] should receive the audio stream from [input 1].
- Meanwhile, [output 2] and [output 3] will not receive any audio stream as denoted by the `-1` values.

An insightful way to think about it is provided on [Apple Developer forums](https://forums.developer.apple.com/forums/thread/15416) and we’ll use the same kind of diagrams here (this example is the same as the one on the Apple Developer forums page).

```
[0, 1] // inputs
 |  |
[0, 1, -1, -1] // outputs
```

Now, to route the stereo input to [output 2] and [output 3] channels, we can simply set the channel map to `[-1, -1, 0, 1]`. Again, a diagram helps to understand:

```
[0, 1] // inputs
 |  |
 |  |_______
 |_______   |
         |  |
[-1, -1, 0, 1] // outputs
```

We can quickly imagine other use cases that the `channelMap` property cover. To come back to the first example: duplicating a mono audio stream to a stereo one would require to set the channel map to `[0, 0]`.
Also, inverting channels to send [input 0] to [output 1] and [input 1] to [output 0]: `channelMap = [1, 0]`.

The `AUAudioUnit.channelMap` property is fairly easy to use and provides numerous mapping possibilities. However, it has limitations for more complex configurations. For example, transforming a stereo stream into a mono stream (sending both [input 0] and [input 1] to [output 0]) is not achievable with this API. Such a transformation cannot be represented simply by setting values in an array.

To set up those more complex mappings, we have to rely on a matrix mixer.

## Using a matrix mixer
A matrix mixer brings a tremendous amount of flexibility when compared to a channel map. But it is also quite tedious to configure it properly, especially as its setup has to happen at a specific moment.

Also, unlike some audio units like `AVAudioUnitTimePitch` that are already exposed as `AVAudioUnit` which inherit from `AVAudioNode`, the matrix mixer audio unit has still to be instantiated using an [`AudioComponentDescription`](https://developer.apple.com/documentation/audiotoolbox/audiocomponentdescription) and configured through the [`AudioUnitSetParameter(_:_:_:_:_:_:)`](https://developer.apple.com/documentation/audiotoolbox/1438454-audiounitsetparameter) C function. Nothing too difficult though, and once functions are written, using it is quite straightforward.

#### Instantiate
Let's first start with a function that instantiates a matrix mixer.

```swift
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
```
Here, a description is provided to the [`AVAudioUnit.instantiate(with:options)`](https://developer.apple.com/documentation/avfaudio/avaudiounit/1390583-instantiate) function. The component type indicates that the audio unit we want to instantiate is a mixer, and the sub component type is really where we specify that we want a matrix mixer. Manufacturer is Apple and the flag parameters are usually set to 0.

#### Setup gains
From what I have gathered from the sources posted at the end of the post, a matrix mixer should have its gains configured. There is a gain for each input channel, each output channel and a global gain. Failing to set a gain will result in silence for the input or output channel, or even silence completely the audio stream for the global gain.

As explained sooner, the matrix mixer needs to be configured with the `AudioUnitSetParameter(_:_:_:_:_:_:)` function so we are going to write a helper function in this post. Here is what it looks like:

```swift
func setAudioUnitValue(
    avAudioUnit: AVAudioUnit,
    for parameterID: AudioUnitParameterID,
    in scope: UInt32,
    element: AudioUnitElement = 0,
    to value: Float
) throws {
    try AudioUnitSetParameter(
        avAudioUnit.audioUnit,
        parameterID,
        scope,
        element,
        value,
        0
    )
    .checkError("Error while calling 'AudioUnitSetParameter'")
}
```
First we pass the `audioUnit` value which is a pointer to the underlying audio unit wrapped by `AVAudioUnit`. Then the `parameterID` will specify what parameter we actually want to set. The scope is a way for CoreAudio to differentiate input, output or global scope when we set a parameter of the audio unit. We are going to use the three scopes to set all the gains. The `element` is scope dependent for this function. This is where we will pass the input or output channel index that we want to set the gain to. Finally, the `value` is the value of the parameter identified by `parameterID`. So for the gain this is going to be the value of the gain we want to set.

> `checkError` is a function mapping `OSStatus` to an error when the result code is not 0. You can find its implementation in the [post resources](https://github.com/MoreDocs/moredocs.github.io/blob/main/_posts_resources/Extensions/OSStatus%2BExtensions.swift).
{: .prompt-info }

With that in place, we are ready to set all the gains:
- the global gain of the audio unit
- all the input channels gains
- all the output channels gains

All gains will have a value of 1 but you are free to modify them and experiment depending on your needs. In this post, only the volumes from one input channel to output channels will be set.

Let's write a function for each type of gains, with comments.

**Global gain**
```swift
func setGlobalGain(on matrixMixerNode: AVAudioUnit) throws {
    try setAudioUnitValue(
        avAudioUnit: matrixMixerNode,
        for: kMatrixMixerParam_Volume,
        in: kAudioUnitScope_Global,
        element: 0xFFFF_FFFF,
        to: 1
    )
}
```
The global gain is set using the specific value `2^32 - 1` as denoted by `0xFFFF_FFFF`, that's the way this API works. The parameter `kMatrixMixerParam_Volume` is going to be used every time we set the gain. Here the scope is global as we are setting the global gain.

**Input gains**
```swift
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
```
Here we set the gain for each input channel using the same `kMatrixMixerParam_Volume` parameter, but passing the input channel index as the element and specifying the input scope.

**Output gains**
```swift
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
```
This function is the same as the one setting the input gains, except we rather iterate over the output channels and use the output scope.

With those gains setup functions ready, let's add a function to set them all up.

```swift
func setupMatrixMixerGains(on matrixMixerNode: AVAudioUnit) throws {
    try setGlobalGain(on: matrixMixerNode)
    try setInputGains(on: matrixMixerNode)
    try setOutputGains(on: matrixMixerNode)
}
```

> Those functions take the matrix mixer node as a parameter which is fine for a demo context but you might want to implement a nice wrapper around a matrix mixer to improve its reusability.
{: .prompt-tip }

We're almost done! Except one question remains: why on earth is this called a matrix mixer?

#### Setup cross points
The matrix mixer API offers to set the gain (or volume) of any input channel to any output channel. Hence the "matrix" term since the visualisation is a 2 dimensional array.
In one of the simplest form, one input channel is mapped to one output channe with the same index - also know as the identity. With a 4×4 matrix, this is the visualisation.

| ↓ Inputs \ Outputs → | 0 | 1 | 2 | 3 |
|------------------|:-:|:-:|:-:|:-:|
| 0                |  1  |  0 | 0  | 0  |
| 1                |  0 |  1  |  0 | 0 |
| 2                |  0 |  0 | 1  |  0 |
| 3                | 0 |  0  | 0  | 1  |

Remember that the values at the cross points are the volumes. So the `1` specify that the audio stream coming from the input channel should be multiplied by 1 when it is forwarded to the output channel. Thus `0` values  effectively silences an input channel for an output channel.

Reusing the second example where the stereo input channels where mapped to the third ([output4]) and fourth ([output 3]) channels, the matrix is:

| ↓ Inputs \ Outputs → | 0 | 1 | 2 | 3 |
|:---------------------|:-:|:-:|:-:|:-:|
| 0                    | 0 | 0 | 1 | 0 |
| 1                    | 0 | 0 | 0 | 1 |

It now appears how powerful this API is as any configuration is possible... But wait! What is the code to achieve that? Let's write the final configuration function.

```swift
func setInputVolume(
    _ volume: Float,
    on matrixMixerNode: AVAudioUnit,
    forInputChannel inputChannelIndex: AVAudioChannelCount,
    toOutputChannels outputChannelIndexes: Set<AVAudioChannelCount>
) throws {
    let outputChannelsCount = matrixMixerNode.outputFormat(forBus: 0).channelCount
    for outputChannelIndex in 0..<outputChannelsCount {
        let volume = outputChannelIndexes.contains(outputChannelIndex) ? volume : 0

        let crossPoint = (inputChannelIndex << AVAudioChannelCount(16)) | outputChannelIndex
        try setAudioUnitValue(
            avAudioUnit: matrixMixerNode,
            for: kMatrixMixerParam_Volume,
            in: kAudioUnitScope_Global,
            element: crossPoint,
            to: volume
        )
    }
}
```
This function takes the volume to be set and the matrix mixer to work on. But more interestingly it takes one input channel and a `Set` of output channels so that the volume value will be set for all positions in the matrix where the input channel crosses an output channel in the set. This is one way to do it of course, and you are free to expose the API you want. That said, for this method,  we iterate over all the output channels and set the volumes at each crossing point. If the output channel is in the set, the volume value will be the one provided in the parameters. Otherwise it will be 0 to silence the input channel in the output channel.

To set this volume value, the matrix mixer API requires to pass a number constructed with bitwise and OR operators as such:
```swift
(inputChannel << 16) | outputChannel
```

> Bitwise and OR operators roles explanation can be found on [Swift documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/).
{: .prompt-tip }

Once the cross point value is ready, the helper function is called once again passing the cross point value as the element and the same volume key.

#### Finalizing setup
With all those functions implemented, we are ready to use the matrix mixer in our code.

```swift
// 1
let inputFormat = engine.inputNode.inputFormat(forBus: 0)
let matrixMixer = try await matrixMixerNode()
engine.attach(matrixMixer)
engine.connect(inputNode, to: matrixMixer, format: inputFormat)
engine.connect(matrixMixer, to: engine.mainMixerNode, format: inputFormat)

try engine.start()

// 2
try setupMatrixMixerGains(matrixMixer)

// 3
for inputChannel in 0..<inputFormat.channelCount {
    setInputVolume(
        1,
        on: matrixMixer,
        forInputChannel: inputChannel,
        toOutputChannels: [0, 1]
    )
}
```
Here's a breakdown:

1\. The matrix mixer is instantiated and added to the engine's graph. We use the input node directly here with its input format.

2\. The matrix mixer gains are setup.

> It is required to call the gains setup *after* the engine has started. Otherwise a runtime failure will be triggered.
{: .prompt-danger }
3\. Each input channel is mapped to the first two output channels.

Naturally, any set of output channels could be used. For instance to transform a stereo input into a mono output, the output channel could be passed as a single value in the set : `[0]`. And in the example with four output channels where a stereo inputs should be routed to the last two output channels, the output channels set would be `[2, 3]`.

### Wrap up
To wrap things up, you can find the code to setup a matrix mixer in the [post resources](https://github.com/MoreDocs/moredocs.github.io/blob/main/_posts_resources/2024-06-15-channel-mapping/MatrixMixer.swift). If you have any question, feel free to ask them in the [Discussion section](https://github.com/MoreDocs/moredocs.github.io/discussions/categories/q-a) of the repository with the title of the post inside brackets: [Channel Mapping].

## Sources
Channel map
- [[Apple Developer Forums] AVAudioEngine and Multiroute](https://forums.developer.apple.com/forums/thread/15416)

Matrix mixer
- [[Apple List] AUMatrixMixer questions](https://lists.apple.com/archives/coreaudio-api/2008/Apr/msg00169.html)
- [[Stack Overflow] How should an AUMatrixMixer be configured in an AVAudioEngine graph?](https://stackoverflow.com/questions/48059405/how-should-an-aumatrixmixer-be-configured-in-an-avaudioengine-graph)
- [[Stack Overflow] Change audio volume of some channels using AVAudioEngine](https://stackoverflow.com/questions/53208006/change-audio-volume-of-some-channels-using-avaudioengine)