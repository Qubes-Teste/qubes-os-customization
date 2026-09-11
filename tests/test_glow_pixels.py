"""Run with: python3 -B -m unittest discover -s tests -p test_glow_pixels.py

These checks need no X server. Geometry uses circular arcs and the union of
rectangles/disks, independently of the renderer's optimized corner bands.
"""

from contextlib import redirect_stdout
import io
import math
import os
from pathlib import Path
import runpy
import struct
import sys
import unittest
from unittest import mock

HUD_FILES = Path(__file__).resolve().parents[1] / "salt/qubes_gui/hud/files"
sys.path.insert(0, str(HUD_FILES))

import glow_pixels


def unpack(width, height, **kwargs):
    sw, sh, data = glow_pixels.render_glow(width, height, **kwargs)
    return sw, sh, struct.unpack(f"={sw * sh}I", data)


def inside_body(x, y, width, height, radius):
    if not (0 <= x <= width and 0 <= y <= height):
        return False
    if radius <= x <= width - radius or radius <= y <= height - radius:
        return True
    return any(
        (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2
        for cx in (radius, width - radius)
        for cy in (radius, height - radius)
    )


class GlowPixelsTests(unittest.TestCase):
    def test_corner_brightness_matches_straight_edge_at_equal_distance(self):
        extent, width, height = 34, 140, 100
        compared = 0
        for radius in (0, 12, 16):
            sw, _, pixels = unpack(width, height, radius=radius, extent=extent)
            edge_x = extent + width // 2
            center = extent + radius
            # Compare every outside pixel in a corner quadrant, including
            # different angles and the cutout inside the owner's bounding box.
            for y in range(center):
                for x in range(center):
                    distance = math.hypot(center - x - 0.5, center - y - 0.5) - radius
                    if not 0.5 <= distance <= extent - 0.5:
                        continue
                    edge_y = extent - distance - 0.5
                    first = math.floor(edge_y)
                    fraction = edge_y - first
                    a = pixels[first * sw + edge_x] >> 24
                    b = pixels[(first + 1) * sw + edge_x] >> 24
                    interpolated = a * (1 - fraction) + b * fraction
                    actual = pixels[y * sw + x] >> 24
                    # Edge interpolation and 8-bit rounding can differ by one
                    # alpha level; the original Gaussian area blur loses much more.
                    self.assertLessEqual(abs(actual - interpolated), 1.0,
                                         (radius, x, y, distance, actual, interpolated))
                    compared += 1
        self.assertGreater(compared, 2000)

    def test_body_is_transparent_but_rounded_cutout_can_glow(self):
        width, height, radius, extent = 81, 55, 12, 9
        sw, sh, pixels = unpack(width, height, radius=radius, extent=extent)
        body_pixels = 0
        for y in range(sh):
            for x in range(sw):
                if inside_body(x + 0.5 - extent, y + 0.5 - extent,
                               width, height, radius):
                    self.assertEqual(pixels[y * sw + x], 0, (x, y))
                    body_pixels += 1
        self.assertGreater(body_pixels, 4000)
        self.assertGreater(pixels[extent * sw + extent] >> 24, 0)

    def test_pixels_are_native_argb_with_premultiplied_rgb(self):
        color = (240, 75, 13)  # Distinct channels detect byte-order mistakes.
        _, _, pixels = unpack(52, 36, radius=11, extent=17, peak=0.87, color=color)
        self.assertTrue(any(pixels))
        for pixel in pixels:
            alpha = pixel >> 24
            self.assertLessEqual(alpha, math.ceil(255 * 0.87))
            for shift, channel in zip((16, 8, 0), color):
                actual = (pixel >> shift) & 255
                self.assertLessEqual(actual, alpha)
                self.assertLessEqual(abs(actual - channel * alpha / 255), 0.5)

    def test_symmetry_and_size_for_tiny_and_fractional_corners(self):
        cases = ((1, 1, 0.5, 1), (1, 1, 0, 34), (2, 3, 1, 3),
                 (17, 11, 5.5, 7), (21, 20, 4.25, 5), (43, 29, 12, 34))
        for width, height, radius, extent in cases:
            with self.subTest(size=(width, height), radius=radius):
                sw, sh, pixels = unpack(width, height, radius=radius, extent=extent)
                self.assertEqual((sw, sh), (width + extent * 2, height + extent * 2))
                for y in range(sh):
                    for x in range(sw):
                        value = pixels[y * sw + x]
                        self.assertEqual(value, pixels[y * sw + sw - x - 1])
                        self.assertEqual(value, pixels[(sh - y - 1) * sw + x])
                        if inside_body(x + 0.5 - extent, y + 0.5 - extent,
                                       width, height, radius):
                            self.assertEqual(value, 0)

    def test_falloff_and_zero_peak(self):
        sw, _, pixels = unpack(80, 60)
        edge = [pixels[y * sw + 74] >> 24 for y in range(34)]
        self.assertEqual(edge, sorted(edge))
        self.assertLessEqual(edge[0], 1)
        self.assertGreater(edge[-1], 120)
        self.assertLessEqual(edge[-1], 128)
        self.assertFalse(any(glow_pixels.render_glow(80, 60, peak=0)[2]))

    def test_rejects_invalid_arguments(self):
        invalid = (
            {"width": 0}, {"width": True}, {"width": 1.2}, {"height": -1},
            {"height": 16385}, {"extent": 0}, {"extent": 257}, {"extent": 1.5},
            {"radius": float("nan")}, {"radius": float("inf")}, {"radius": -1},
            {"radius": 257}, {"radius": 31}, {"peak": -0.1}, {"peak": 1.1},
            {"peak": float("nan")}, {"peak": 10 ** 400}, {"peak": True},
            {"color": (0, 255, 256)}, {"color": [True, 2, 3]},
            {"color": (0, 1)}, {"color": "rgb"},
        )
        for overrides in invalid:
            with self.subTest(arguments=overrides):
                arguments = {"width": 80, "height": 60, **overrides}
                with self.assertRaises(ValueError):
                    glow_pixels.render_glow(**arguments)

    def test_pixel_limit_includes_padding_and_precedes_allocation(self):
        with mock.patch.object(glow_pixels, "MAX_PIXELS", 100):
            self.assertEqual(len(glow_pixels.render_glow(8, 8, extent=1)[2]), 400)
            with mock.patch.object(glow_pixels, "_bands", side_effect=AssertionError):
                with self.assertRaises(ValueError):
                    glow_pixels.render_glow(9, 8, extent=1)
        # Guard both rendering paths against allocating the oversized output.
        with mock.patch.object(glow_pixels, "_bands", side_effect=AssertionError), \
             mock.patch.object(glow_pixels, "bytes", side_effect=AssertionError, create=True):
            for peak in (0, 0.5):
                with self.subTest(peak=peak), self.assertRaises(ValueError):
                    glow_pixels.render_glow(16384, 16384, peak=peak)


class HudGlowCheckTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.helper = runpy.run_path(str(HUD_FILES / "hud-glow"))

    def fake_library(self, missing=None):
        class Library:
            def __init__(self):
                self.functions = {}

            def __getattr__(self, name):
                if name == missing:
                    raise AttributeError(name)
                if name not in self.functions:
                    self.functions[name] = mock.Mock(
                        side_effect=AssertionError("--check must not call an X11 function"))
                return self.functions[name]
        return Library()

    def test_check_binds_all_libraries_as_root_without_display(self):
        libraries = [self.fake_library() for _ in range(3)]
        with mock.patch.object(self.helper["C"], "CDLL", side_effect=libraries) as loader, \
             mock.patch.object(sys, "argv", ["hud-glow", "--check"]), \
             mock.patch.dict(os.environ, {}, clear=True), \
             mock.patch.object(os, "geteuid", return_value=0), \
             redirect_stdout(io.StringIO()):
            self.helper["main"]()
        self.assertEqual(loader.call_args_list,
                         [mock.call("libX11.so.6"), mock.call("libXrender.so.1"),
                          mock.call("libXfixes.so.3")])
        self.assertIn("XOpenDisplay", libraries[0].functions)
        self.assertIn("XRenderFindVisualFormat", libraries[1].functions)
        self.assertIn("XFixesSetWindowShapeRegion", libraries[2].functions)
        self.assertFalse(any(fn.called for lib in libraries for fn in lib.functions.values()))

    def test_check_rejects_missing_library(self):
        with mock.patch.object(self.helper["C"], "CDLL", side_effect=OSError("missing")):
            with self.assertRaises(OSError):
                self.helper["X11"](check_only=True)

    def test_check_rejects_missing_input_shape_symbol(self):
        libraries = [self.fake_library(), self.fake_library(),
                     self.fake_library("XFixesSetWindowShapeRegion")]
        with mock.patch.object(self.helper["C"], "CDLL", side_effect=libraries):
            with self.assertRaises(AttributeError):
                self.helper["X11"](check_only=True)


if __name__ == "__main__":
    unittest.main()
