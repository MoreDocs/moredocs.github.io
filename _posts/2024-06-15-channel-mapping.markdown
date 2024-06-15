---
layout: post
title:  "Channel Mapping"
date:   2024-06-15 15:47:23 +0200
categories: [Audio, Channel Mapping]
tags: [audio, routing, channel-mapping, article]
---
Channel mapping is a way of describing how input channels are mapped to output channels. The term "input" here refers to the input of a processing unit. It can be an unit that simply mixes audio like `AVAudioMixerNode`, or one that is used to retrieve audio from input devices such as microphones, MIDI devices and so on - typically the audio unit used in `AVAudioEngine.inputNode`.