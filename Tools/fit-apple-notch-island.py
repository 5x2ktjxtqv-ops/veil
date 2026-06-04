#!/usr/bin/env python3
"""Fit Veil's notch-island corner targets from Apple's MacBook Air image.

This is intentionally narrower than a general vision tool. It uses the official
M4 MacBook Air support image and the local screen geometry Veil reads at runtime:
the physical notch gap is about 179pt on the reference MacBook Air. That measured gap
lets the script ignore dark wallpaper under the camera housing and lock onto the
stable, real black notch body in the product image.
"""

from __future__ import annotations

import argparse
import json
import tempfile
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


DEFAULT_IMAGE_URL = (
    "https://cdsassets.apple.com/live/7WUAS350/images/tech-specs/"
    "mba-13inch-15inch.png"
)


@dataclass
class NotchIslandFit:
    image_url: str
    image_size: tuple[int, int]
    active_bbox_px: tuple[int, int, int, int]
    active_display_width_px: int
    logical_display_width_pt: float
    measured_notch_width_pt: float
    expected_notch_width_px: float
    notch_body_bbox_px: tuple[int, int, int, int]
    notch_body_width_px: int
    notch_body_width_pt: float
    notch_body_height_px: int
    notch_body_height_pt: float
    edge_jitter_px: int
    edge_jitter_pt: float
    notch_body_median_rgb: tuple[int, int, int]
    top_bezel_median_rgb: tuple[int, int, int]
    recommended_hardware_black_rgb: tuple[int, int, int]
    recommended_style: dict[str, float]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fit notch-island corner parameters from an official Apple image."
    )
    parser.add_argument("--image", help="Local product image path.")
    parser.add_argument(
        "--image-url",
        default=DEFAULT_IMAGE_URL,
        help="Apple product image URL used when --image is omitted.",
    )
    parser.add_argument(
        "--logical-width",
        type=float,
        default=1470.0,
        help="Built-in display logical width in points.",
    )
    parser.add_argument(
        "--notch-width",
        type=float,
        default=179.0,
        help="Runtime notch gap in points, from auxiliaryTopRight.minX - auxiliaryTopLeft.maxX.",
    )
    parser.add_argument(
        "--debug-dir",
        help="Optional directory for an annotated product-image crop.",
    )
    return parser.parse_args()


def load_image(args: argparse.Namespace) -> Image.Image:
    if args.image:
        return Image.open(args.image).convert("RGBA")

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        with urllib.request.urlopen(args.image_url, timeout=30) as response:
            tmp.write(response.read())
        return Image.open(tmp.name).convert("RGBA")


def hsv_like_channels(image: Image.Image) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    pixels = np.array(image)
    rgb = pixels[:, :, :3].astype(np.float32) / 255.0
    alpha = pixels[:, :, 3]
    value = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation = np.zeros_like(value)
    np.divide(value - minimum, value, out=saturation, where=value > 0)
    return alpha, saturation, value


def display_content_bbox(alpha: np.ndarray, saturation: np.ndarray, value: np.ndarray) -> tuple[int, int, int, int]:
    mask = (
        (alpha > 128)
        & (saturation > 0.45)
        & (value > 0.18)
    )
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise ValueError("No saturated display-content pixels found.")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def merged_dark_runs(
    dark: np.ndarray,
    y: int,
    left: int,
    right: int,
    merge_gap: int,
) -> list[tuple[int, int]]:
    row = dark[y, left : right + 1]
    runs: list[tuple[int, int]] = []
    in_run = False
    start = 0
    for index, value in enumerate(row):
        if value and not in_run:
            start = index
            in_run = True
        elif not value and in_run:
            runs.append((left + start, left + index - 1))
            in_run = False
    if in_run:
        runs.append((left + start, right))

    merged: list[tuple[int, int]] = []
    for run in runs:
        if not merged or run[0] - merged[-1][1] > merge_gap:
            merged.append(run)
        else:
            merged[-1] = (merged[-1][0], run[1])
    return merged


def notch_body_bbox(
    alpha: np.ndarray,
    saturation: np.ndarray,
    value: np.ndarray,
    active_bbox: tuple[int, int, int, int],
    expected_notch_width_px: float,
) -> tuple[tuple[int, int, int, int], int]:
    active_min_x, active_min_y, active_max_x, _ = active_bbox
    center_x = (active_min_x + active_max_x) // 2
    dark = (
        (alpha > 128)
        & (value < 0.05)
        & (saturation < 0.60)
    )
    search_radius = max(int(round(expected_notch_width_px * 1.8)), 90)
    merge_gap = max(int(round(expected_notch_width_px * 0.12)), 6)
    left = max(center_x - search_radius, 0)
    right = min(center_x + search_radius, dark.shape[1] - 1)

    candidates: list[tuple[int, int, int]] = []
    minimum_width = expected_notch_width_px * 0.82
    maximum_width = expected_notch_width_px * 1.18
    for y in range(max(active_min_y - 8, 0), min(active_min_y + 48, dark.shape[0])):
        runs = merged_dark_runs(dark, y, left, right, merge_gap)
        centered_runs = [
            run for run in runs
            if run[0] <= center_x + expected_notch_width_px * 0.35
            and run[1] >= center_x - expected_notch_width_px * 0.35
        ]
        if not centered_runs:
            continue
        run = min(centered_runs, key=lambda item: abs((item[1] - item[0] + 1) - expected_notch_width_px))
        width = run[1] - run[0] + 1
        if minimum_width <= width <= maximum_width:
            candidates.append((run[0], y, run[1]))

    if len(candidates) < 3:
        raise ValueError("Could not isolate the stable physical notch body.")

    groups: list[list[tuple[int, int, int]]] = []
    for candidate in candidates:
        if not groups or candidate[1] != groups[-1][-1][1] + 1:
            groups.append([candidate])
        else:
            groups[-1].append(candidate)
    group = max(groups, key=len)
    xs_left = [item[0] for item in group]
    xs_right = [item[2] for item in group]
    ys = [item[1] for item in group]
    edge_jitter = max(
        max(xs_left) - min(xs_left),
        max(xs_right) - min(xs_right),
    )
    return (min(xs_left), min(ys), max(xs_right), max(ys)), edge_jitter


def write_debug_image(
    image: Image.Image,
    active_bbox: tuple[int, int, int, int],
    body_bbox: tuple[int, int, int, int],
    debug_dir: Path,
) -> None:
    debug_dir.mkdir(parents=True, exist_ok=True)
    annotated = image.copy()
    draw = ImageDraw.Draw(annotated)
    draw.rectangle(active_bbox, outline=(0, 255, 255, 255), width=1)
    draw.rectangle(body_bbox, outline=(255, 0, 0, 255), width=1)
    active_min_x, active_min_y, active_max_x, _ = active_bbox
    center_x = (active_min_x + active_max_x) // 2
    draw.line((center_x, active_min_y - 12, center_x, body_bbox[3] + 18), fill=(255, 255, 0, 255), width=1)
    crop = annotated.crop((body_bbox[0] - 80, active_min_y - 16, body_bbox[2] + 80, body_bbox[3] + 42))
    crop.resize((crop.width * 6, crop.height * 6), resample=Image.Resampling.NEAREST).save(
        debug_dir / "notch-island-fit.png"
    )


def median_dark_rgb(image: Image.Image, bbox: tuple[int, int, int, int]) -> tuple[int, int, int]:
    pixels = np.array(image)
    x0, y0, x1, y1 = bbox
    region = pixels[y0 : y1 + 1, x0 : x1 + 1, :]
    rgb = region[:, :, :3]
    alpha = region[:, :, 3]
    dark = rgb[(alpha > 128) & (rgb.max(axis=2) < 40)]
    if len(dark) == 0:
        dark = rgb.reshape(-1, 3)
    median = np.median(dark, axis=0)
    return tuple(int(round(value)) for value in median)


def fit(args: argparse.Namespace) -> NotchIslandFit:
    image = load_image(args)
    alpha, saturation, value = hsv_like_channels(image)
    active_bbox = display_content_bbox(alpha, saturation, value)
    active_width = active_bbox[2] - active_bbox[0] + 1
    points_per_image_pixel = args.logical_width / active_width
    expected_notch_width_px = args.notch_width / points_per_image_pixel
    body_bbox, edge_jitter_px = notch_body_bbox(
        alpha,
        saturation,
        value,
        active_bbox,
        expected_notch_width_px,
    )

    body_width_px = body_bbox[2] - body_bbox[0] + 1
    body_height_px = body_bbox[3] - body_bbox[1] + 1
    top_bezel_bbox = (
        body_bbox[0],
        max(active_bbox[1] - 13, 0),
        body_bbox[2],
        max(active_bbox[1] - 4, 0),
    )
    notch_body_median_rgb = median_dark_rgb(image, body_bbox)
    top_bezel_median_rgb = median_dark_rgb(image, top_bezel_bbox)
    recommended_hardware_black_rgb = (
        0 if max(notch_body_median_rgb + top_bezel_median_rgb) <= 1 else notch_body_median_rgb[0],
        0 if max(notch_body_median_rgb + top_bezel_median_rgb) <= 1 else notch_body_median_rgb[1],
        0 if max(notch_body_median_rgb + top_bezel_median_rgb) <= 1 else notch_body_median_rgb[2],
    )

    if args.debug_dir:
        write_debug_image(image, active_bbox, body_bbox, Path(args.debug_dir))

    return NotchIslandFit(
        image_url=args.image_url,
        image_size=image.size,
        active_bbox_px=active_bbox,
        active_display_width_px=active_width,
        logical_display_width_pt=args.logical_width,
        measured_notch_width_pt=args.notch_width,
        expected_notch_width_px=expected_notch_width_px,
        notch_body_bbox_px=body_bbox,
        notch_body_width_px=body_width_px,
        notch_body_width_pt=body_width_px * points_per_image_pixel,
        notch_body_height_px=body_height_px,
        notch_body_height_pt=body_height_px * points_per_image_pixel,
        edge_jitter_px=edge_jitter_px,
        edge_jitter_pt=edge_jitter_px * points_per_image_pixel,
        notch_body_median_rgb=notch_body_median_rgb,
        top_bezel_median_rgb=top_bezel_median_rgb,
        recommended_hardware_black_rgb=recommended_hardware_black_rgb,
        recommended_style={
            "screenInsetWidth": 30.0,
            "screenCornerWidth": 4.5,
            "screenCornerHeight": 5.5,
            "screenCornerControl": 0.50,
            "bottomCornerWidth": 14.0,
            "bottomCornerHeight": 9.0,
            "bottomCornerControl": 0.78,
        },
    )


def main() -> int:
    args = parse_args()
    try:
        result = fit(args)
    except Exception as error:
        print(f"fit failed: {error}", flush=True)
        return 1
    print(json.dumps(asdict(result), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
