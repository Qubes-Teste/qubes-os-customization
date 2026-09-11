# Qubes HUD managed file. Owner: salt/qubes_gui/hud.
"""Distance-based glow pixels for Qubes HUD.

No X11 calls, files, network access, or third-party modules are used here.
The caller places the surface at (owner_x - extent, owner_y - extent).
"""

from functools import lru_cache
import math
import struct


MAX_DIMENSION = 16384
MAX_EXTENT = 256
MAX_RADIUS = 256
MAX_PIXELS = 16 * 1024 * 1024  # At most 64 MiB of returned ARGB pixels.
_TRANSPARENT = b"\0\0\0\0"


def _integer(name, value, minimum, maximum):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"{name} must be an integer in {minimum}..{maximum}")
    return value


def _number(name, value, minimum, maximum):
    if type(value) not in (int, float):
        raise ValueError(f"{name} must be a finite number")
    try:
        value = float(value)
    except OverflowError as error:
        raise ValueError(f"{name} must be a finite number") from error
    if not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError(f"{name} must be in {minimum}..{maximum}")
    return value


@lru_cache(maxsize=8)
def _profile(extent):
    """Use Picom 12.4's Gaussian-width criterion, without its area convolution.

    Choose sigma so the normalized outermost kernel row weighs 0.5/256.
    A one-dimensional edge integral then gives the same broad falloff at
    every angle. Truncating and renormalizing its tail avoids a hard cutoff.
    This approximates the stock discrete edge profile, not its corner blur.
    """
    low, high = 0.0, 2.0 * extent
    if 0.5 / 256.0 < 1.0 / (2.0 * extent):
        while high - low > 0.01:
            sigma = (low + high) / 2.0
            normalized_row = (
                math.exp(-0.5 * (extent / sigma) ** 2)
                / (math.sqrt(2.0 * math.pi) * sigma)
                / math.erf(extent / (math.sqrt(2.0) * sigma))
            )
            if normalized_row > 0.5 / 256.0:
                high = sigma
            else:
                low = sigma
        sigma = (low + high) / 2.0
    else:
        sigma = high
    scale = 1.0 / (math.sqrt(2.0) * sigma)
    tail = math.erfc(extent * scale)
    return scale, tail


def _alpha(distance, extent, peak, profile):
    if distance <= 0.0 or distance >= extent:
        return 0
    scale, tail = profile
    value = peak * (math.erfc(distance * scale) - tail) / (1.0 - tail)
    return max(0, min(255, int(value * 255.0 + 0.5)))


@lru_cache(maxsize=8)
def _bands(radius, extent, peak, color):
    """Cache only bounded corner/edge data, never complete window surfaces."""
    packed = []
    for alpha in range(256):
        red, green, blue = ((channel * alpha + 127) // 255 for channel in color)
        packed.append(struct.pack("=I", alpha << 24 | red << 16 | green << 8 | blue))
    profile = _profile(extent)

    def pixel(distance):
        return packed[_alpha(distance, extent, peak, profile)]

    count = math.ceil(extent + radius)
    corner_rows = []
    for y in range(count):
        dy = max(0.0, extent + radius - (y + 0.5))
        row = [
            pixel(math.hypot(max(0.0, extent + radius - (x + 0.5)), dy) - radius)
            for x in range(count)
        ]
        corner_rows.append((b"".join(row), b"".join(reversed(row))))
    side = [pixel(extent - (x + 0.5)) for x in range(extent)]
    tops = tuple(pixel(extent - (y + 0.5)) for y in range(count))
    return tuple(corner_rows), b"".join(side), b"".join(reversed(side)), tops


def render_glow(width, height, radius=0, extent=34, peak=0.50, color=(25, 211, 255)):
    """Return (surface_width, surface_height, native-endian ARGB32 bytes).

    Width/height describe the owner's outer frame, without glow. RGB is
    premultiplied by the quantized alpha. Alpha depends only on the positive
    signed distance from each pixel center to that frame's rounded rectangle;
    all pixels inside the body are transparent. Peak is the alpha approached
    just outside the boundary. The falloff reaches zero at ``extent`` pixels.

    Dimensions are limited to 16384 each, extent to 256, radius to both 256
    and half the smaller owner dimension, and output to 64 MiB. The caller
    must separately bound how many returned surfaces it retains. Eight corner
    caches contain at most 16 MiB of pixel data; assembling a surface needs its
    output plus at most 33 MiB of temporary row data, rather than a second
    full mutable image. Invalid arguments raise ValueError before allocation.
    """
    width = _integer("width", width, 1, MAX_DIMENSION)
    height = _integer("height", height, 1, MAX_DIMENSION)
    extent = _integer("extent", extent, 1, MAX_EXTENT)
    radius = _number("radius", radius, 0, min(MAX_RADIUS, width / 2, height / 2))
    peak = _number("peak", peak, 0, 1)
    if type(color) not in (tuple, list) or len(color) != 3:
        raise ValueError("color must contain exactly three integer RGB channels")
    color = tuple(_integer("color channel", channel, 0, 255) for channel in color)
    surface_width, surface_height = width + 2 * extent, height + 2 * extent
    if surface_width * surface_height > MAX_PIXELS:
        raise ValueError("glow surface exceeds the 64 MiB pixel limit")
    if peak == 0:
        return surface_width, surface_height, bytes(surface_width * surface_height * 4)

    corners, left_side, right_side, tops = _bands(radius, extent, peak, color)
    corner_width = min(len(corners), surface_width // 2)
    corner_height = min(len(corners), surface_height // 2)
    middle_width = surface_width - 2 * corner_width
    rows = [None] * surface_height
    for y in range(corner_height):
        left, right = corners[y]
        row = left[:corner_width * 4] + tops[y] * middle_width + right[-corner_width * 4:]
        rows[y] = rows[surface_height - y - 1] = row
    middle_row = left_side + _TRANSPARENT * width + right_side
    for y in range(corner_height, surface_height - corner_height):
        rows[y] = middle_row
    return surface_width, surface_height, b"".join(rows)
