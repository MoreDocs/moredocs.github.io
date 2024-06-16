---
layout: post
title:  Channel Mapping
date:   2024-06-15 15:47:23 +0200
categories: [Audio, Channel Mapping]
tags: [article, macOS, iOS, Swift, AVAudioEngine, audio, routing, channel mapping]
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

The easiest API to operate a channel mapping is the [`channelMap`](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/2143054-channelmap) property of `AUAudioUnit`, which is an Obj-C wrapper around `AudioUnit` from CoreAudio. It can be set on some specific audio nodes in the graph of an `AVAudioEngine`. From my experience, only on `AVAudioEngine.outputNode` and `AVAudioPlayerNode`. Setting it on an output node is fairly easy:

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
 |  ________
 ________   |
         |  |
[-1, -1, 0, 1] // outputs
```

We can quickly image other use cases that the `channelMap` property cover. To come back to the first example: duplicating a mono audio stream to a stereo one would require to set the channel map to `[0, 0]`.
Also, inverting channels to send [input 0] to [output 1] and [input 1] to [output 0]: `channelMap = [1, 0]`.

The `AUAudioUnit.channelMap` property is quite easy to use and yet offers already many possible mappings. That said, more complex ones cannot be achieved with the help of this API. For instance, it's not possible to transform a stereo stream to a mono one, i.e. to send both [input 0] and [input 1] to [output 0]. It just cannot be expressed through values in an array.

The `AUAudioUnit.channelMap` property is fairly easy to use and provides numerous mapping possibilities. However, it has limitations for more complex configurations. For example, transforming a stereo stream into a mono stream (sending both [input 0] and [input 1] to [output 0]) is not achievable with this API. Such a transformation cannot be represented simply by setting values in an array.

To set up those more complex mappings, we have to rely on a matrix mixer.

## Using a matrix mixer
## Sources
#### Channel map

- [[Apple Developer Forums] AVAudioEngine and Multiroute](https://forums.developer.apple.com/forums/thread/15416)

#### Matrix mixer

- [[Apple List] AUMatrixMixer questions](https://lists.apple.com/archives/coreaudio-api/2008/Apr/msg00169.html)
- [[Stack Overflow] How should an AUMatrixMixer be configured in an AVAudioEngine graph?](https://stackoverflow.com/questions/48059405/how-should-an-aumatrixmixer-be-configured-in-an-avaudioengine-graph)
- [[Stack Overflow] Change audio volume of some channels using AVAudioEngine](https://stackoverflow.com/questions/53208006/change-audio-volume-of-some-channels-using-avaudioengine)