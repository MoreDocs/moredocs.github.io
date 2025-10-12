---
layout: post
title:  Programmatically logout a user in Swift
date:   2024-06-19 20:26:05 +0200
categories: [Administration, User Management]
tags: [how to, macOS, Swift, administration]
author: alexis
description: How to logout a user in Swift as well as restarting, shutting down and putting the computer to sleep.
---

## Sending Events

The Apple documentation explains that to programmatically shutdown, restart, put to sleep or logout a machine is possible by sending an Apple event. From what I understand, macOS allows to send and receive Apple events. I interpret that a bit like distributed notifications, maybe more powerful but also more complex to use.
From an application, it’s possible to send an event to the loginwindow process to ask to shutdown, restart, put to sleep the computer or logout the user.

Of course when C is involved, it’s not that easy. So in this article, we’ll build an `EventService` with a single static function send that will take an event type as a parameter. For instance

```swift
EventService.send(event: .restartComputer)
```

## Models

From the function above, we can extract two types:

`EventService` which is an enum with no cases. Why using an enum? When implementing features that do not have a state, and are merely a collection of functions, I think it’s better to be clear about it. Using an enum with no cases in Swift is common for purpose like name-spacing because an enum with no cases cannot be instantiated. So the `EventService` is really only a name to access to the Apple event services through functions. If we were to use a struct, it could be instantiated unless the init() is private which requires to mark it like so.


AppleEventType which will gather the 4 possibles event types we want to send: shutdown, restart, put to sleep and logout.
So let’s start with that.

```swift
enum EventService {}

// MARK: - Logic

// logic will come here

// MARK: - Models

extension EventService {

    struct AppleEventType {
        let description: String
        let osType: OSType
    }
}

// MARK: - Events

extension EventService.AppleEventType {

    static let shutdownComputer = Self(
        description: "Shut down the computer", 
        osType: kAEShutDown
    )
    
    static let restartComputer = Self(
        description: "Restart the computer", 
        osType: kAERestart
    )
    
    static let putComputerToSleep = Self(
        description: "Asleep the computer", 
        osType: kAESleep
    )
    
    static let logoutUser = Self(
        description: "Logout the user", 
        osType: kAEReallyLogOut
    )
}
```

We declare an `AppleEventType` struct that will be used only through its static members. For those events, we'll need the description for display purposes and the `OSType` value to pass the system events API.

If you are wondering why we define `AppleEventType` inside the `EventService` type, that’s to avoid cluttering the namespace and because the struct is closely related to the first one. Also, we declare the four events that we want to use in this article.

## Logic

The only function we want to write takes an `AppleEventType` as parameter. We add the logic where the comment "logic will come here" lies.

```swift
extension EventService {

    static func send(event eventType: AppleEventType) throws {

    }
}
```
The function is throwing because we can get an error in the steps below, and we’ll have to forward it.
The skeleton is ready for implementation. To send an Apple event to the loginwindow process, here are the three steps from the doc:

- Create an address targeting the loginwindow process.
- Create an Apple event with the provided event type using the created address in step 1.
- Send the Apple event created in step 2.

Doesn’t seem too hard! Of course we’ll have some pointers dance to do for each step.

#### Step 1: Create the Address

To create an address, we have to call the function `AECreateDesc`. It takes four parameters:
- The way to identify the process. We’ll give it a serial number here so we'll use the key `keyProcessSerialNumber`.
- The serial number of the process we want to target. Held in a `ProcessSerialNumber` struct (couldn’t find anything on this struct but that’s what the doc uses).
- The size (in bytes) of the serial number type. Given in Swift by `MemoryLayout.size`.
- A pointer to an AEAddressDesc value where the result will be copied.

Very often, C functions will return a value that indicates whether an error occurred. We’ll have to check that the returned value is `noErr` else we’ll throw an error with a relevant message.

Before we call the function, we actually have to get the process serial number of `loginwindow`. The doc states that we can obtain it by instantiating a `ProcessSerialNumber` with the parameters `0` and `kSystemProcess`:

```swift
var loginWindowSerialNumber = ProcessSerialNumber(
    highLongOfPSN: 0,
    lowLongOfPSN: UInt32(kSystemProcess)
)
```

Here is the first step.

```swift
// 1
var loginWindowSerialNumber = ProcessSerialNumber(
    highLongOfPSN: 0,
    lowLongOfPSN: UInt32(kSystemProcess)
)

var targetDesc = AEAddressDesc()

// 2
defer { AEDisposeDesc(&targetDesc) }

// 3
try AECreateDesc(
    keyProcessSerialNumber,
    &loginWindowSerialNumber,
    MemoryLayout<ProcessSerialNumber>.size,
    &targetDesc
)
.checkError("Unable to create the description of the app")
```

And some remarks:
1. We get the loginwindow serial number, and instantiate an empty address and `OSErr` for the function to fill them.
2. Since we'll throw an error if creating the app description fails, we use a defer statement to ensure that the target description value is released as mentioned in the doc. Frankly I am not sure it’s needed since it’s a structure. But I may not understand why so let’s do what the doc asks. It’s not a big deal to call one function anyway.
3. We create the address.
4. If the function `AECreateDesc` returns something else than a status not indicating an error, we throw an error with an explanation.

> `checkError` is a function mapping `OSErr` to an error when the result code is not 0. You can find its implementation in the [post resources](https://github.com/MoreDocs/moredocs.github.io/blob/main/_posts_resources/Extensions/OSErr%2BExtensions.swift).
{: .prompt-info }

#### Step 2: Create the Apple Event

To make an Apple event, we will have to use the function `AECreateAppleEvent`. It takes 6 parameters:
- An event class which is required to identify the event. I could not find anything else than `kCoreEventClass` and it’s the one we are going to use.
- The event ID. That’s where we will indicate a shutdown, restart, put to sleep or logout event.
- The address of the process the event is destined to. So we’ll pass the `AEAddressDesc` created in step 1 (as a pointer).
- To differentiate events, it’s possible to provide a custom ID or to let the system make one automatically. We’ll take the second option for this parameter.
- To group events, it’s possible to provide a unique ID here, but we’ll ignore that and pass a `kAnyTransactionID`.
- Finally, a pointer where the resulting event should be written at.

```swift
// 1
var event = AppleEvent()
defer { AEDisposeDesc(&event) }

try AECreateAppleEvent(
    kCoreEventClass,
    eventType.eventID,
    &targetDesc,
    AEReturnID(kAutoGenerateReturnID),
    AETransactionID(kAnyTransactionID),
    &event
)
.checkError("Unable to create an Apple Event for the app description")
```

We create the event to get the result and call the `AECreateAppleEvent` function. Don’t worry about `AEReturnID` and `AETransactionID`. They respectively are type aliases for `Int16` and `Int32`. Using them makes the code clearer about what is manipulated. And again, if we get a value that is an error, we throw a relevant message.

#### Step 3: Send the Event

The function we need here is `AESendMessage`. It takes 4 parameters:
- The event to send.
- A pointer to a reply to fill of type `AppleEvent`.
- The mode to send the message. We could specify that we want to wait for a reply, or to queue it to an event queue. But here we don’t care about it so we’ll pass `kAENoReply`. It seems that we can work on the bits to also specify other flags like for the interaction but it’s not required.
- The time our app is willing to wait to get a response. This is provided in ticks of the CPU. The doc advises to pass the default value (about one minute), but we’ll pass an arbitrary value of 1000 ticks. I don’t think it’s relevant in our use case since we are sending specific events.

Here is the implementation.

```swift
// 1
var reply = AppleEvent()
defer { AEDisposeDesc(&reply) }

try AESendMessage(
    &event,
    &reply,
    AESendMode(kAENoReply),
    1000
)
.checkError("Error while sending the event \(eventType)")
```

> `checkError` is a function mapping `OSStatus` to an error when the result code is not 0. You can find its implementation in the [post resources](https://github.com/MoreDocs/moredocs.github.io/blob/main/_posts_resources/Extensions/OSStatus%2BExtensions.swift).
{: .prompt-info }

- We send the event, getting the response in reply.
- If we get an error, we throw it.
- We release the event and reply variables as stated in the doc.

You can find the overall implementation in the [post resources](https://github.com/MoreDocs/moredocs.github.io/blob/main/_posts_resources/2024-06-19-programatically-logout-user-in-swift/EventService.swift).
 
#### Add the Entitlements

Just before we can send events, we have to add the following key to the app entitlement:

```xml
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.apple.loginwindow</string>
</array>
```

#### Playground

If you want to try it, here is a simple SwiftUI view with a picker and a button. You’ll first have to extend `EventService.AppleEventType` to `Identifiable` and `CaseIterable`:

```swift
extension EventService.AppleEventType: CaseIterable, Identifiable {
    var id: String { rawValue }
}
```
Then use the view.
```swift
struct ContentView: View {

    @State private var eventType: EventService.AppleEventType = .shutdownComputer

    var body: some View {
        VStack {
            Picker("Action", selection: $eventType) {
                ForEach(EventService.AppleEventType.allCases) { event in
                    Text(event.rawValue).tag(event)
                }
            }

            HStack {
                Spacer()
                Button("Send") {
                    do {
                        try EventService.send(event: eventType)
                    } catch {
                        print(error, error.localizedDescription)
                    }
                }
            }
        }
        .padding()
        .frame(width: 300, height: 100)
    }
}
```