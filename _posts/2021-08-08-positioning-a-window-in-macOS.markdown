---
layout: post
title: Positioning a Window in macOS
date:   2021-08-08 10:00:00 +0200
categories: [UI, Utils]
tags: [how to, macOS, AppKit]
author: alexis
description: Some ideas to position a NSWindow with AppKit.
---

Most often when working with windows on macOS, it’s not necessary to think about where the window is positioned. The user might move it or resize it after it has been opened. That said, I did face situations where putting the window at a specific position was needed. For example with panels and help windows that should remain at a specific place while the user is doing something else. In this article, we’ll see how to easily position a window horizontally and vertically. The two axis combination will allow us to get 3x3 = 9 different possibilities like « top-left », « center », or « bottom-center ». Lastly, a padding option should be available to detach the window from the edges.

The final code can be found on this [gist](https://gist.github.com/ABridoux/b935c21c7ead92033d39b357fae6366b). A function will be made available on `NSWindow` will be provided.

## The Position Model

I like to start by thinking about how it should be possible to use a feature I am implementing, then to start implementing the model. It would be neat if we could specify the window position like so:

```swift
// window: NSWindow
window.setPosition(vertical: .top, horizontal: .left, padding: 20)
```

Looking at it, it seems that the best tool for the vertical and horizontal positions is an enum. Then a struct could wrap them with the padding parameter.

> Of course, there are several ways to model that. We could for instance stick to two enums and provide the logic directly in the `setPosition(vertical:horizontal:padding:)` function. But I like being able to pass the created position if necessary.
{: .prompt-info }

Alright, with the remarks above, let’s see what the `Position` type looks like.

```swift
extension NSWindow { // 1

  struct Position {
    // 2
    static let defaultPadding: CGFloat = 16
    // 3
    var vertical: Vertical
    var horizontal: Horizontal
    var padding = Self.defaultPadding
  }
}
```

Here are some remarks:

1. To avoid cluttering the namespace, I prefer to define the `Position` structure inside the `NSWindow` type since it closely related to it.
2. I think it could be useful to have a default padding from edges to make the padding property specification optional.
3. The two axis enums will be defined inside the Position type for the same reason Position is defined inside `NSWindow`.

Here are the enums:

```swift
extension NSWindow.Position {

  enum Horizontal {
    case left, center, right
  }

  enum Vertical {
    case top, center, bottom
  }
}
```

So that’s it for the models! Now let’s think about the actual logic to compute a position.

## Positioning Logic
Naturally, the function to compute the position should return a `CGPoint` that will be used as the window’s `origin` property. AppKit axis starts in the bottom-left corner on the screen. Thus it’s easy to get the proper origin for the window for the bottom-left corner: we just have to add the padding and we’re good to go. But for the other positions, we’ll have to take the window’s size into account to make sure it's properly aligned. This should not be too hard to overcome though.

Separating the vertical and horizontal axis allows us to reason with each one as isolated. So let’s start with the vertical one.

```swift
extension NSWindow.Position.Vertical {

  func valueFor(
    screenRange: Range<CGFloat>,
    height: CGFloat,
    padding: CGFloat
  ) -> CGFloat {
      switch self {
          case .top: return screenRange.upperBound - height - padding
          case .center: return (screenRange.upperBound + screenRange.lowerBound - height) / 2
          case .bottom: return screenRange.lowerBound + padding
      }
  }
}
```

Let’s take a look at the parameters:

- `screenRange`: at my first very first attempt to position a window in a screen, I only used the screen size, so the height here. But then I realized that macOS would give a NSScreen specific frame when several monitors are used. So we could have a second monitor which origin doesn’t start at (0, 0). It depends on how the screens layout is customized by the user. Thus, to ensure the window is properly set in the right screen, the screen axis bounds are passed.
- `height`: that’s the window height. It’s used when the position is not at the top.
- `padding`: when using padding, it has to be added to the computation of the origin.

Now for the cases:

- `bottom`: the easiest case. We add the padding to the screen origin
- `center`: the center of the screen is provided by (screenRange.upperBound - screenRange.lowerBound) / 2. As we are setting the origin of the window, which is the bottom-left corner, removing half of the height is needed to center the overall window's height in the middle. Note that the padding is irrelevant here.
- `top`: we simply remove the height of the window as well as the padding.

Since the same computations go for the horizontal axis, they are omitted. We are now ready to implement the `Position` method that takes a window and a screen rectangles to compute the origin of the window.

```swift
extension NSWindow.Position {

  func value(forWindow windowRect: CGRect, inScreen screenRect: CGRect) -> CGPoint {
    let xPosition = horizontal.valueFor(
      screenRange: screenRect.minX..<screenRect.maxX,
      width: windowRect.width,
      padding: padding
    )

    let yPosition = vertical.valueFor(
      screenRange: screenRect.minY..<screenRect.maxY,
      height: windowRect.height,
      padding: padding
    )

    return CGPoint(x: xPosition, y: yPosition)
  }
}
```

Horizontal and vertical computations are similar. The screen range is provided by the min/max properties of the frame depending on the axis. Then we pass either the window’s `width` for the horizontal position and the `height` for the vertical position.

## AppKit Extensions
With this function implemented, it’s easy to define the function to set a `NSWindow` position.

```swift
extension NSWindow {

  func setPosition(_ position: Position, in screen: NSScreen?) {
    guard let visibleFrame = (screen ?? self.screen)?.visibleFrame else { return }
    let origin = position.value(forWindow: frame, inScreen: visibleFrame)
    setFrameOrigin(origin)
  }
}
```

This function takes a `Position` parameter, as well as an optional `NSScreen` to put the window on. If no screen is provided, it will be the actual screen the window is on. A quick note about the `visibleFrame` property. This is to take the menu bar and the dock (if not automatically hidden) into account. If we don’t consider it, we will work with the full screen frame although it is not available. Then we get the origin’s point from the `position` parameter and assign it to the window’s origin.

For convenience, another function is implemented.

```swift
func setPosition(
  vertical: Position.Vertical,
  horizontal: Position.Horizontal,
  padding: CGFloat = Position.defaultPadding,
  screen: NSScreen? = nil
) {
  set(
    position: Position(vertical: vertical, horizontal: horizontal, padding: padding),
    in: screen
  )
}
```

This way, we get the desired function to set a window position, for instance in the `AppDelegate`.

```swift
window.setPosition(vertical: .top, horizontal: .center)
// or
window.setPosition(vertical: .bottom, horizontal: .left, padding: 20)
// or
window.setPosition(vertical: .center, horizontal: .center, screen: .main)
```

> All screens are accessible through the array `NSScreen.screens`
{: .prompt-tip }

Pretty nice, don’t you think?