# Display Edge Fit

状态：Compatibility notes  
日期：2026-06-04

## Why This Exists

Modern MacBook built-in displays have rounded upper display corners, and many
notched models leave the lower display corners visually rectangular in normal
desktop use. Veil's bottom-corner mask is a small visual correction: it makes
the lower corners align with the upper display radius so all four corners read
as one intentional screen shape.

This may be the strongest open-source product wedge because it is:

- immediately visible
- independent from private workflow monitoring preferences
- useful before a settings UI exists
- easy to explain without asking for network, VPN, or telemetry access

## Apple Product Fit

Best fit:

- MacBook Air 13-inch and 15-inch models with the modern rounded-corner display shape.
- MacBook Pro 14-inch and 16-inch models with the modern notched display shape.

Lower fit:

- older rectangular MacBook displays without a notch/top safe area
- iMac and most external displays
- Studio Display and other rectangular desktop displays

Apple's public specifications describe the current MacBook Air and MacBook Pro
displays as having rounded-corner viewable areas, while desktop displays such as
Studio Display are specified as standard rectangular panels. The implementation
should therefore treat built-in rounded/notched MacBook displays as the primary
target and let rectangular displays no-op unless a future user preference
explicitly enables decorative corner masks.

Reference pages:

- Apple MacBook Air specs: https://www.apple.com/macbook-air/specs/
- Apple MacBook Pro specs: https://www.apple.com/macbook-pro/specs/
- Apple Studio Display specs: https://www.apple.com/studio-display/specs/

## Runtime Detection

The current safe default is capability-based, not model-name-based.

Primary inputs:

- `NSScreen.safeAreaInsets`
- `NSScreen.auxiliaryTopLeftArea`
- `NSScreen.auxiliaryTopRightArea`
- `NSScreen.backingScaleFactor`
- `NSScreen.frame` and `visibleFrame`

Apple API references:

- `NSScreen.safeAreaInsets`: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets
- `NSScreen.auxiliaryTopLeftArea`: https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea
- `NSScreen.auxiliaryTopRightArea`: https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytoprightarea

Current behavior:

- bottom-corner masks target screens with top safe area plus both top auxiliary areas
- notch capsule targets the notched screen when available
- visual-only notch capsule does not fall back to a blank capsule on rectangular displays
- status signals can still use a fallback HUD position on rectangular displays when explicitly enabled

## Adaptation Risks

Known fit risks:

- different MacBook generations can have slightly different physical radii
- display scale and pixel alignment can make a correct point radius look soft or heavy
- fullscreen video, games, and screen sharing should not have lower-corner masks drawn over them
- external displays may be rectangular, already physically rounded, or scaled through unusual modes
- color matching depends on using the same calibrated hardware black in notch and corner masks

Current mitigations:

- radius is configurable through `VEIL_BOTTOM_CORNER_RADIUS`
- mask windows are pass-through and per-display
- fullscreen cover detection hides masks after a short debounce
- unsupported displays fail closed by rendering no corner-mask windows

## Product Decision

Ship the visual module as `auto` by default. Keep adapter monitoring opt-in.

The open-source pitch should lead with:

> "Make modern MacBook display corners feel finished."

Then the optional status surface can be framed as a second layer for people who
want their notch area to carry useful signals.
