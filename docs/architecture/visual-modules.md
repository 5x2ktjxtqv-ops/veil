# Veil Visual Modules

状态：OSS product direction  
日期：2026-06-04

## Product Role

Veil's open-source core is display-edge refinement. Status signals are useful,
but they are optional overlays on top of the visual fit layer.

The default product should feel valuable even when every signal adapter is off:

- top notch blend on supported notched MacBook displays
- bottom-corner mask that makes all four screen corners read as one rounded set
- per-display no-op behavior when a display does not need the correction

## Module Contract

Each visual module should declare:

| Field | Purpose |
| --- | --- |
| `id` | Stable identifier, such as `notch-capsule` or `bottom-corner-mask`. |
| `displayName` | Name for a future settings UI. |
| `defaultMode` | `auto`, `on`, or `off`. Fresh installs should use `auto` for safe display-fit modules. |
| `capabilityCheck` | Per-display logic that decides whether the module should render. |
| `geometryInputs` | The macOS display fields the module needs, such as safe area, auxiliary areas, scale, and frame. |
| `fallback` | How the module fails closed without leaving visible artifacts. |

Visual modules should not start telemetry providers, shell out to tools, query
network state, or own status adapter policy.

## Built-In Modules

### `notch-capsule`

Purpose: visually blend the physical notch into a matte black capsule.

Capability:

- target a display with a top safe area
- prefer displays with `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`
- hide on rectangular displays when status signals are off

### `bottom-corner-mask`

Purpose: add black lower-corner masks so the bottom corners visually match the
rounded upper display corners.

Capability:

- target built-in notched MacBook-style displays with top safe area and auxiliary areas
- render one pass-through mask window per lower corner
- hide under fullscreen cover to avoid drawing over fullscreen video, games, or screen sharing

The current default radius is `21.2pt`, derived from the Apple MacBook Air M4
reference image fit recorded in `docs/design/bottom-corner-apple-fit.md`.

### `status-signal-hud`

Purpose: render compact values and indicator dots inside the notch capsule.

This is visually hosted by the capsule, but it is not part of the visual module
baseline. It requires `--status-signals`, `VEIL_STATUS_SIGNALS=1`, a persisted
or explicit adapter approval, or another explicit adapter enablement.

## Future Configuration Shape

The future settings file can stay small and local-first:

```json
{
  "visualModules": {
    "notchCapsule": "auto",
    "bottomCornerMask": "auto"
  },
  "statusSignals": {
    "enabled": false,
    "order": ["memory", "cpu", "network", "disk"]
  }
}
```

`auto` means "render only when the current display geometry clearly supports
the module." It should not mean "guess aggressively."
