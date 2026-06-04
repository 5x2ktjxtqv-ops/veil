# Notch Island Official Image Fit

## Reference

- Machine: MacBook Air, `Mac16,12`, 13-inch M4, 2025.
- Apple spec page: https://support.apple.com/en-la/122209
- Apple product image: https://cdsassets.apple.com/live/7WUAS350/images/tech-specs/mba-13inch-15inch.png
- Runtime notch gap on this machine: about `179pt`, from
  `auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX`.

This fit uses the official product image as a geometry reference, but it does
not blindly copy the raw physical notch. Veil's HUD is an extended notch island:
it covers the real notch and adds side wings for rotating status text. The raw
Apple notch is therefore used as the direction of travel: tighten the visible
corners and reduce the pill-like lower curve without changing the data layout.

## Command

```sh
python3 Tools/fit-apple-notch-island.py \
  --image-url https://cdsassets.apple.com/live/7WUAS350/images/tech-specs/mba-13inch-15inch.png \
  --debug-dir /tmp/veil-apple-notch-fit
```

## Result

```json
{
  "active_bbox_px": [119, 229, 881, 724],
  "active_display_width_px": 763,
  "expected_notch_width_px": 92.9095238095238,
  "measured_notch_width_pt": 179.0,
  "notch_body_bbox_px": [453, 229, 545, 243],
  "notch_body_width_px": 93,
  "notch_body_width_pt": 179.1743119266055,
  "notch_body_height_px": 15,
  "notch_body_height_pt": 28.89908256880734,
  "notch_body_median_rgb": [0, 0, 0],
  "top_bezel_median_rgb": [0, 0, 0],
  "recommended_hardware_black_rgb": [0, 0, 0]
}
```

Recommended Veil style:

```text
screenInsetWidth: 30
screenCornerWidth: 4.5
screenCornerHeight: 5.5
screenCornerControl: 0.50
bottomCornerWidth: 14
bottomCornerHeight: 9
bottomCornerControl: 0.78
```

The previous `18 x 12` lower corner made the island read closer to a generic
capsule. The refined `14 x 9` lower corner keeps the side wings soft enough for
text, while moving the silhouette toward the tighter native notch body visible
in Apple's image.

## Black Calibration

The official image samples resolve to pure black for both the physical notch
body and the top display border. Veil therefore keeps the fill at explicit sRGB
`#000000` and shares that value with the bottom corner masks through
`VeilHardwareBlack`.

The visible refinement is in edge coverage: the notch outline keeps a very light
`0.18` alpha black stroke to cover anti-aliased edge shimmer without making the
shape look like a heavier black capsule. The bottom corner masks use the same
fill color and rely on supersampled antialiasing at the cutout edge.
