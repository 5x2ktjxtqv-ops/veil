#!/usr/bin/env python3
"""Fit Veil's bottom-corner mask from an official Apple product image.

The tool uses Apple's front-facing MacBook Air product image as a reference for
the top display content corner. It intentionally fits the visible display
content corner rather than the larger aluminum/display-lid silhouette.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
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
class CornerFit:
    image_url: str
    image_size: tuple[int, int]
    alpha_threshold: int
    saturation_threshold: float
    value_threshold: float
    active_bbox_px: tuple[int, int, int, int]
    active_aspect: float
    expected_aspect: float
    top_left_origin_px: tuple[int, int]
    tangent_radius_px: tuple[int, int]
    radius_x_pt: float
    radius_y_pt: float
    recommended_radius_pt: float
    superellipse_exponent: float
    equation_rms_error: float
    sample_count: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fit bottom-corner mask parameters from an Apple product image."
    )
    parser.add_argument(
        "--image",
        help="Local product image path. If omitted, --image-url is downloaded.",
    )
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
        "--logical-height",
        type=float,
        default=956.0,
        help="Built-in display logical height in points. Kept for reporting.",
    )
    parser.add_argument(
        "--native-width",
        type=float,
        default=2560.0,
        help="Built-in display native pixel width. Kept for reporting.",
    )
    parser.add_argument(
        "--native-height",
        type=float,
        default=1664.0,
        help="Built-in display native pixel height. Kept for reporting.",
    )
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=128,
        help="Minimum alpha for a product-image pixel to be considered visible.",
    )
    parser.add_argument(
        "--saturation-threshold",
        type=float,
        default=0.45,
        help="Minimum HSV-like saturation for display-content pixels.",
    )
    parser.add_argument(
        "--value-threshold",
        type=float,
        default=0.18,
        help="Minimum HSV-like value for display-content pixels.",
    )
    parser.add_argument(
        "--debug-dir",
        help="Optional directory for diagnostic crop/mask images.",
    )
    return parser.parse_args()


def load_image(args: argparse.Namespace) -> tuple[Image.Image, Path | None]:
    if args.image:
        return Image.open(args.image).convert("RGBA"), Path(args.image)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        with urllib.request.urlopen(args.image_url, timeout=30) as response:
            tmp.write(response.read())
        path = Path(tmp.name)

    return Image.open(path).convert("RGBA"), path


def content_mask(
    image: Image.Image,
    alpha_threshold: int,
    saturation_threshold: float,
    value_threshold: float,
) -> np.ndarray:
    pixels = np.array(image)
    rgb = pixels[:, :, :3].astype(np.float32) / 255.0
    alpha = pixels[:, :, 3]
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation = np.zeros_like(maximum)
    np.divide(maximum - minimum, maximum, out=saturation, where=maximum > 0)
    value = maximum

    return (
        (alpha > alpha_threshold)
        & (saturation > saturation_threshold)
        & (value > value_threshold)
    )


def bounded_mask(mask: np.ndarray) -> tuple[np.ndarray, int, int, int, int]:
    y_grid, x_grid = np.indices(mask.shape)
    height, width = mask.shape
    upper_left = (
        mask
        & (x_grid < width * 0.5)
        & (y_grid < height * 0.55)
    )
    ys, xs = np.where(upper_left)
    if len(xs) == 0:
        raise ValueError("No display-content pixels found in the upper-left search area.")

    all_ys, all_xs = np.where(mask)
    return mask, int(all_xs.min()), int(all_ys.min()), int(all_xs.max()), int(all_ys.max())


def first_visible_origin(mask: np.ndarray) -> tuple[int, int]:
    y_grid, x_grid = np.indices(mask.shape)
    height, width = mask.shape
    upper_left = (
        mask
        & (x_grid < width * 0.5)
        & (y_grid < height * 0.55)
    )
    ys, xs = np.where(upper_left)
    return int(xs.min()), int(ys.min())


def envelope_points(mask: np.ndarray, x0: int, y0: int, span: int = 72) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
    row_points: list[tuple[int, int]] = []
    col_points: list[tuple[int, int]] = []

    for y in range(y0, min(y0 + span, mask.shape[0])):
        columns = np.where(mask[y, x0 : min(x0 + span, mask.shape[1])])[0]
        if len(columns) > 0:
            row_points.append((int(x0 + columns.min()), int(y)))

    for x in range(x0, min(x0 + span, mask.shape[1])):
        rows = np.where(mask[y0 : min(y0 + span, mask.shape[0]), x])[0]
        if len(rows) > 0:
            col_points.append((int(x), int(y0 + rows.min())))

    return row_points, col_points


def tangent_radii(
    row_points: list[tuple[int, int]],
    col_points: list[tuple[int, int]],
    x0: int,
    y0: int,
) -> tuple[int, int]:
    try:
        radius_y = next(y - y0 for x, y in row_points if x == x0)
        radius_x = next(x - x0 for x, y in col_points if y == y0)
    except StopIteration as error:
        raise ValueError("Could not identify top/left tangencies in the content boundary.") from error

    if radius_x <= 0 or radius_y <= 0:
        raise ValueError(f"Invalid fitted radii: ({radius_x}, {radius_y})")

    return int(radius_x), int(radius_y)


def fit_superellipse_exponent(
    row_points: list[tuple[int, int]],
    col_points: list[tuple[int, int]],
    x0: int,
    y0: int,
    radius_x: int,
    radius_y: int,
) -> tuple[float, float, int]:
    points = sorted(
        set(
            [
                (x, y)
                for x, y in row_points
                if y - y0 <= radius_y and x - x0 <= radius_x + 10
            ]
            + [
                (x, y)
                for x, y in col_points
                if x - x0 <= radius_x and y - y0 <= radius_y + 10
            ]
        )
    )
    if not points:
        raise ValueError("No boundary samples found for superellipse fitting.")

    best_exponent = 2.0
    best_rms = math.inf
    for step in range(111):
        exponent = 1.0 + step * 0.05
        residuals = []
        for x, y in points:
            u = max(0.0, min((x - x0) / radius_x, 1.0))
            v = max(0.0, min((y - y0) / radius_y, 1.0))
            residuals.append((1 - u) ** exponent + (1 - v) ** exponent - 1)

        rms = math.sqrt(sum(value * value for value in residuals) / len(residuals))
        if rms < best_rms:
            best_rms = rms
            best_exponent = exponent

    return best_exponent, best_rms, len(points)


def write_debug_images(
    image: Image.Image,
    mask: np.ndarray,
    row_points: list[tuple[int, int]],
    col_points: list[tuple[int, int]],
    x0: int,
    y0: int,
    radius_x: int,
    radius_y: int,
    debug_dir: Path,
) -> None:
    debug_dir.mkdir(parents=True, exist_ok=True)
    image.save(debug_dir / "apple-product-reference.png")

    mask_image = Image.fromarray(mask.astype(np.uint8) * 255)
    mask_image.save(debug_dir / "display-content-mask.png")

    annotated = image.copy()
    draw = ImageDraw.Draw(annotated)
    for point in row_points + col_points:
        draw.point(point, fill=(255, 210, 0, 255))

    draw.rectangle((x0, y0, x0 + radius_x, y0 + radius_y), outline=(255, 0, 0, 255), width=1)
    draw.line((x0, y0 + radius_y, x0 + radius_x, y0), fill=(0, 255, 120, 255), width=1)
    crop = annotated.crop((max(x0 - 28, 0), max(y0 - 28, 0), x0 + radius_x + 72, y0 + radius_y + 72))
    crop.resize((crop.width * 6, crop.height * 6), resample=Image.Resampling.NEAREST).save(
        debug_dir / "top-left-corner-fit.png"
    )


def fit(args: argparse.Namespace) -> CornerFit:
    image, _ = load_image(args)
    mask = content_mask(
        image,
        alpha_threshold=args.alpha_threshold,
        saturation_threshold=args.saturation_threshold,
        value_threshold=args.value_threshold,
    )
    _, active_min_x, active_min_y, active_max_x, active_max_y = bounded_mask(mask)
    active_width = active_max_x - active_min_x + 1
    active_height = active_max_y - active_min_y + 1
    expected_aspect = args.native_width / args.native_height

    x0, y0 = first_visible_origin(mask)
    row_points, col_points = envelope_points(mask, x0, y0)
    radius_x, radius_y = tangent_radii(row_points, col_points, x0, y0)
    exponent, rms, sample_count = fit_superellipse_exponent(
        row_points,
        col_points,
        x0,
        y0,
        radius_x,
        radius_y,
    )

    radius_x_pt = radius_x * args.logical_width / active_width
    radius_y_pt = radius_y * args.logical_width / active_width
    recommended_radius_pt = (radius_x_pt + radius_y_pt) / 2.0

    if args.debug_dir:
        write_debug_images(
            image,
            mask,
            row_points,
            col_points,
            x0,
            y0,
            radius_x,
            radius_y,
            Path(args.debug_dir),
        )

    return CornerFit(
        image_url=args.image_url,
        image_size=image.size,
        alpha_threshold=args.alpha_threshold,
        saturation_threshold=args.saturation_threshold,
        value_threshold=args.value_threshold,
        active_bbox_px=(active_min_x, active_min_y, active_max_x, active_max_y),
        active_aspect=active_width / active_height,
        expected_aspect=expected_aspect,
        top_left_origin_px=(x0, y0),
        tangent_radius_px=(radius_x, radius_y),
        radius_x_pt=radius_x_pt,
        radius_y_pt=radius_y_pt,
        recommended_radius_pt=recommended_radius_pt,
        superellipse_exponent=exponent,
        equation_rms_error=rms,
        sample_count=sample_count,
    )


def main() -> int:
    args = parse_args()
    try:
        result = fit(args)
    except Exception as error:
        print(f"fit failed: {error}", file=sys.stderr)
        return 1

    print(json.dumps(asdict(result), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
