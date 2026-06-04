# Bottom Corner Official Image Fit

## Reference

- Machine: MacBook Air, `Mac16,12`, 13-inch M4, 2025.
- Apple spec page: https://support.apple.com/en-la/122209
- Apple product image: https://cdsassets.apple.com/live/7WUAS350/images/tech-specs/mba-13inch-15inch.png

The fit intentionally uses the screen-content corner inside the display, not the
larger aluminum/display-lid silhouette. The lid silhouette produces a much
larger radius and is not the shape Veil is trying to mirror at the bottom of the
desktop.

## Command

```sh
python3 Tools/fit-apple-display-corner.py \
  --image-url https://cdsassets.apple.com/live/7WUAS350/images/tech-specs/mba-13inch-15inch.png
```

## Result

```json
{
  "active_aspect": 1.5383064516129032,
  "expected_aspect": 1.5384615384615385,
  "active_bbox_px": [119, 229, 881, 724],
  "top_left_origin_px": [119, 229],
  "tangent_radius_px": [10, 12],
  "radius_x_pt": 19.26605504587156,
  "radius_y_pt": 23.119266055045873,
  "recommended_radius_pt": 21.19266055045872
}
```

Veil rounds this to a `21.2pt` default bottom-corner mask radius. The previous
`24pt` value was close visually, but this default is now traceable to the Apple
reference image and can be regenerated without human visual judgment.

The bottom corner fill uses the shared `VeilHardwareBlack` sRGB `#000000`, the
same calibrated black used by the notch island. This keeps the simulated
non-display corner aligned with Apple's sampled notch/body black instead of
letting SwiftUI and AppKit choose separate implicit black definitions.

The fitted `superellipse_exponent` is treated as diagnostic only. The M4 support
image uses a dark wallpaper with diagonal highlights near the top-left corner, so
the most stable reusable parameter is the tangent-derived radius rather than the
noisier curve exponent.
