#!/usr/bin/env python3
"""Generate a clean poster-friendly humanoid marker graphic."""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "resources" / "reference_samples" / "head100_2026-03-07" / "mocap_head100.csv"
OUT_DIR = ROOT / "outputs" / "figures" / "poster_marker_humanoid_20260325"
SVG_PATH = OUT_DIR / "poster_marker_humanoid.svg"
EDITORIAL_SVG_PATH = OUT_DIR / "poster_marker_humanoid_editorial.svg"
INFOGRAPHIC_SVG_PATH = OUT_DIR / "poster_marker_humanoid_infographic.svg"

WIDTH = 1400
HEIGHT = 2100

Point = Tuple[float, float]


def read_marker_names(path: Path) -> List[str]:
    with path.open(newline="") as handle:
        rows = list(csv.reader(handle))

    name_row = rows[3]
    kind_row = rows[6]
    axis_row = rows[7]

    names: List[str] = []
    seen = set()
    for i in range(2, len(name_row) - 2):
        if kind_row[i].strip() != "Position":
            continue
        if axis_row[i : i + 3] != ["X", "Y", "Z"]:
            continue
        name = name_row[i].split(":", 1)[-1].strip()
        if not name or name == "Skeleton 001" or "Unlabeled" in name or name in seen:
            continue
        seen.add(name)
        names.append(name)
    return names


def mirror_x(point: Point) -> Point:
    return (WIDTH - point[0], point[1])


def pt(x: float, y: float) -> Point:
    return (x, y)


def place_finger(
    coords: Dict[str, Point],
    base_name: str,
    side: str,
    points: List[Point],
    extra_tip_name: str | None = None,
) -> None:
    names = [f"{side}{base_name}1", f"{side}{base_name}2", f"{side}{base_name}3"]
    if extra_tip_name:
        names.append(f"{side}{extra_tip_name}")
    for name, point in zip(names, points):
        coords[name] = point


def build_marker_layout() -> Dict[str, Point]:
    coords: Dict[str, Point] = {}

    coords.update(
        {
            "HeadTop": pt(700, 150),
            "HeadLeft": pt(620, 265),
            "HeadRight": pt(780, 265),
            "Head": pt(700, 255),
            "HeadFront": pt(700, 330),
            "Neck": pt(700, 410),
            "BackTop": pt(700, 485),
            "ChestTop": pt(700, 535),
            "BackLeft": pt(645, 595),
            "Chest": pt(700, 620),
            "BackRight": pt(755, 595),
            "ChestLow": pt(700, 710),
            "Ab": pt(700, 805),
            "WaistLFront": pt(615, 930),
            "WaistLBack": pt(645, 975),
            "WaistCBack": pt(700, 995),
            "WaistRBack": pt(755, 975),
            "WaistRFront": pt(785, 930),
        }
    )

    left_arm = {
        "LShoulderTop": pt(560, 470),
        "LShoulderBack": pt(535, 515),
        "LShoulder": pt(560, 540),
        "LUArmHigh": pt(500, 620),
        "LUArm": pt(480, 690),
        "LElbowOut": pt(440, 805),
        "LFArm": pt(425, 885),
        "LWristOut": pt(415, 1030),
        "LHandIn": pt(430, 1110),
        "LHand": pt(408, 1140),
        "LHandOut": pt(372, 1148),
    }
    coords.update(left_arm)

    place_finger(coords, "Thumb", "L", [pt(392, 1098), pt(360, 1065), pt(330, 1033)], "Thumb")
    coords["LThumb"] = pt(374, 1080)
    place_finger(coords, "Index", "L", [pt(388, 1165), pt(360, 1205), pt(336, 1245)], "Index")
    coords["LIndex"] = pt(350, 1225)
    place_finger(coords, "Middle", "L", [pt(405, 1175), pt(390, 1222), pt(376, 1270)])
    place_finger(coords, "Ring", "L", [pt(425, 1170), pt(424, 1214), pt(422, 1258)])
    place_finger(coords, "Pinky", "L", [pt(446, 1155), pt(454, 1192), pt(468, 1226)], "Pinky")
    coords["LPinky"] = pt(458, 1208)

    right_pairs = {
        "RShoulderTop": "LShoulderTop",
        "RShoulderBack": "LShoulderBack",
        "RShoulder": "LShoulder",
        "RUArmHigh": "LUArmHigh",
        "RUArm": "LUArm",
        "RElbowOut": "LElbowOut",
        "RFArm": "LFArm",
        "RWristOut": "LWristOut",
        "RHandIn": "LHandIn",
        "RHand": "LHand",
        "RHandOut": "LHandOut",
        "RThumb1": "LThumb1",
        "RThumb2": "LThumb2",
        "RThumb3": "LThumb3",
        "RThumb": "LThumb",
        "RIndex1": "LIndex1",
        "RIndex2": "LIndex2",
        "RIndex3": "LIndex3",
        "RIndex": "LIndex",
        "RMiddle1": "LMiddle1",
        "RMiddle2": "LMiddle2",
        "RMiddle3": "LMiddle3",
        "RRing1": "LRing1",
        "RRing2": "LRing2",
        "RRing3": "LRing3",
        "RPinky1": "LPinky1",
        "RPinky2": "LPinky2",
        "RPinky3": "LPinky3",
        "RPinky": "LPinky",
    }
    for target, source in right_pairs.items():
        coords[target] = mirror_x(coords[source])

    left_leg = {
        "LThighSide": pt(625, 1095),
        "LThighFront": pt(645, 1135),
        "LThigh": pt(625, 1220),
        "LKneeOut": pt(610, 1455),
        "LShin": pt(595, 1570),
        "LAnkleOut": pt(582, 1800),
        "LFoot": pt(590, 1865),
        "LHeel": pt(562, 1905),
        "LToe": pt(618, 1915),
        "LToeIn": pt(606, 1945),
        "LToeTip": pt(628, 1964),
        "LToeOut": pt(650, 1938),
    }
    coords.update(left_leg)
    for target, source in {
        "RThighSide": "LThighSide",
        "RThighFront": "LThighFront",
        "RThigh": "LThigh",
        "RKneeOut": "LKneeOut",
        "RShin": "LShin",
        "RAnkleOut": "LAnkleOut",
        "RFoot": "LFoot",
        "RHeel": "LHeel",
        "RToe": "LToe",
        "RToeIn": "LToeIn",
        "RToeTip": "LToeTip",
        "RToeOut": "LToeOut",
    }.items():
        coords[target] = mirror_x(coords[source])

    return coords


def svg_circle(cx: float, cy: float, r: float, fill: str, stroke: str | None = None, stroke_width: float = 0, opacity: float = 1.0) -> str:
    stroke_attr = "" if stroke is None else f' stroke="{stroke}" stroke-width="{stroke_width:.1f}"'
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}"{stroke_attr} opacity="{opacity:.3f}"/>'


def svg_ellipse(cx: float, cy: float, rx: float, ry: float, fill: str, opacity: float = 1.0) -> str:
    return f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" opacity="{opacity:.3f}"/>'


def svg_line(a: Point, b: Point, color: str, width: float, opacity: float = 1.0) -> str:
    return (
        f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" '
        f'stroke="{color}" stroke-width="{width:.1f}" stroke-linecap="round" opacity="{opacity:.3f}"/>'
    )


def svg_polyline(points: Iterable[Point], color: str, width: float, opacity: float = 1.0) -> str:
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    return (
        f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width:.1f}" '
        f'stroke-linecap="round" stroke-linejoin="round" opacity="{opacity:.3f}"/>'
    )


def svg_path(d: str, fill: str, opacity: float = 1.0) -> str:
    return f'<path d="{d}" fill="{fill}" opacity="{opacity:.3f}"/>'


def build_body(style: str) -> List[str]:
    pieces: List[str] = []
    if style == "editorial":
        body_fill = "#D8D5CD"
        body_shadow = "#C4BDB3"
        body_line = "#8E8881"
        head_fill = "#DBD6CE"
        head_shadow = "#C9C1B6"
        limb_fill = "#D4D0C7"
        hand_fill = "#D1CBC2"
        foot_fill = "#CEC8BF"
    else:
        body_fill = "#D5DED8"
        body_shadow = "#BAC7C0"
        body_line = "#8EA096"
        head_fill = "#D8E1DB"
        head_shadow = "#C2CEC7"
        limb_fill = "#D1D9D3"
        hand_fill = "#CDD6D0"
        foot_fill = "#CBD4CE"

    neck_path = (
        "M 664 406 "
        "Q 681 386 700 386 "
        "Q 719 386 736 406 "
        "L 740 448 "
        "Q 720 458 700 458 "
        "Q 680 458 660 448 Z"
    )
    torso_path = (
        "M 575 470 "
        "C 616 438 658 430 700 430 "
        "C 742 430 784 438 825 470 "
        "C 860 498 876 554 880 632 "
        "C 884 734 874 828 852 904 "
        "C 832 970 782 1010 700 1018 "
        "C 618 1010 568 970 548 904 "
        "C 526 828 516 734 520 632 "
        "C 524 554 540 498 575 470 Z"
    )
    pelvis_path = (
        "M 600 942 "
        "C 632 920 664 912 700 914 "
        "C 736 912 768 920 800 942 "
        "C 820 980 816 1024 798 1062 "
        "C 770 1110 736 1138 700 1142 "
        "C 664 1138 630 1110 602 1062 "
        "C 584 1024 580 980 600 942 Z"
    )
    left_arm_path = (
        "M 556 480 "
        "C 518 512 490 580 470 672 "
        "C 448 774 432 888 414 1018 "
        "C 408 1070 398 1116 384 1148 "
        "C 374 1170 356 1172 346 1154 "
        "C 336 1136 338 1108 344 1074 "
        "C 358 954 374 836 394 722 "
        "C 414 610 442 526 486 470 "
        "C 504 448 536 450 556 480 Z"
    )
    right_arm_path = (
        "M 844 480 "
        "C 882 512 910 580 930 672 "
        "C 952 774 968 888 986 1018 "
        "C 992 1070 1002 1116 1016 1148 "
        "C 1026 1170 1044 1172 1054 1154 "
        "C 1064 1136 1062 1108 1056 1074 "
        "C 1042 954 1026 836 1006 722 "
        "C 986 610 958 526 914 470 "
        "C 896 448 864 450 844 480 Z"
    )
    left_leg_path = (
        "M 634 1038 "
        "C 618 1120 608 1234 600 1378 "
        "C 592 1528 584 1698 572 1888 "
        "C 570 1918 556 1938 538 1938 "
        "C 520 1938 510 1918 512 1882 "
        "C 522 1684 534 1512 548 1348 "
        "C 560 1226 574 1120 590 1028 Z"
    )
    right_leg_path = (
        "M 766 1038 "
        "C 782 1120 792 1234 800 1378 "
        "C 808 1528 816 1698 828 1888 "
        "C 830 1918 844 1938 862 1938 "
        "C 880 1938 890 1918 888 1882 "
        "C 878 1684 866 1512 852 1348 "
        "C 840 1226 826 1120 810 1028 Z"
    )
    left_hand_path = (
        "M 350 1144 "
        "C 346 1180 356 1206 382 1218 "
        "C 404 1228 428 1222 442 1202 "
        "C 452 1188 454 1168 448 1148 "
        "C 440 1124 420 1110 396 1110 "
        "C 372 1112 356 1122 350 1144 Z"
    )
    right_hand_path = (
        "M 1050 1144 "
        "C 1054 1180 1044 1206 1018 1218 "
        "C 996 1228 972 1222 958 1202 "
        "C 948 1188 946 1168 952 1148 "
        "C 960 1124 980 1110 1004 1110 "
        "C 1028 1112 1044 1122 1050 1144 Z"
    )
    left_foot_path = (
        "M 500 1942 "
        "C 514 1918 546 1904 586 1904 "
        "C 624 1904 652 1912 668 1930 "
        "C 682 1946 676 1964 650 1972 "
        "C 628 1978 594 1980 554 1978 "
        "C 526 1976 506 1968 494 1958 "
        "C 486 1952 488 1946 500 1942 Z"
    )
    right_foot_path = (
        "M 900 1942 "
        "C 886 1918 854 1904 814 1904 "
        "C 776 1904 748 1912 732 1930 "
        "C 718 1946 724 1964 750 1972 "
        "C 772 1978 806 1980 846 1978 "
        "C 874 1976 894 1968 906 1958 "
        "C 914 1952 912 1946 900 1942 Z"
    )
    shoulder_left = (548, 476)
    shoulder_right = (852, 476)

    if style == "editorial":
        pieces.append(svg_ellipse(700, 268, 122, 164, head_fill, 0.985))
        pieces.append(svg_ellipse(700, 272, 104, 146, head_shadow, 0.10))
        pieces.append(svg_path(neck_path, body_fill, 0.98))
        pieces.append(svg_path(torso_path, body_fill, 0.94))
        pieces.append(svg_path(pelvis_path, body_shadow, 0.55))
        pieces.append(svg_circle(shoulder_left[0], shoulder_left[1], 46, limb_fill, opacity=0.94))
        pieces.append(svg_circle(shoulder_right[0], shoulder_right[1], 46, limb_fill, opacity=0.94))
        pieces.append(svg_path(left_arm_path, limb_fill, 0.94))
        pieces.append(svg_path(right_arm_path, limb_fill, 0.94))
        pieces.append(svg_path(left_hand_path, hand_fill, 0.94))
        pieces.append(svg_path(right_hand_path, hand_fill, 0.94))
        pieces.append(svg_path(left_leg_path, limb_fill, 0.94))
        pieces.append(svg_path(right_leg_path, limb_fill, 0.94))
        pieces.append(svg_path(left_foot_path, foot_fill, 0.94))
        pieces.append(svg_path(right_foot_path, foot_fill, 0.94))
        pieces.append(svg_line(pt(700, 442), pt(700, 986), body_line, 6, 0.05))
        pieces.append(svg_line(pt(608, 476), pt(792, 476), body_line, 3, 0.05))
    else:
        pieces.append(svg_ellipse(700, 268, 124, 164, head_fill, 0.985))
        pieces.append(svg_ellipse(700, 272, 108, 146, head_shadow, 0.14))
        pieces.append(svg_path(neck_path, body_fill, 0.98))
        pieces.append(svg_path(torso_path, body_fill, 0.965))
        pieces.append(svg_path(pelvis_path, body_shadow, 0.68))
        pieces.append(svg_circle(shoulder_left[0], shoulder_left[1], 48, limb_fill, opacity=0.965))
        pieces.append(svg_circle(shoulder_right[0], shoulder_right[1], 48, limb_fill, opacity=0.965))
        pieces.append(svg_path(left_arm_path, limb_fill, 0.965))
        pieces.append(svg_path(right_arm_path, limb_fill, 0.965))
        pieces.append(svg_path(left_hand_path, hand_fill, 0.965))
        pieces.append(svg_path(right_hand_path, hand_fill, 0.965))
        pieces.append(svg_path(left_leg_path, limb_fill, 0.965))
        pieces.append(svg_path(right_leg_path, limb_fill, 0.965))
        pieces.append(svg_path(left_foot_path, foot_fill, 0.965))
        pieces.append(svg_path(right_foot_path, foot_fill, 0.965))
        pieces.append(svg_line(pt(700, 442), pt(700, 986), body_line, 8, 0.09))
        pieces.append(svg_line(pt(600, 476), pt(800, 476), body_line, 4, 0.07))
        pieces.append(svg_line(pt(626, 946), pt(774, 946), body_line, 4, 0.07))
    return pieces


def build_svg(marker_points: Dict[str, Point], ordered_names: List[str], style: str) -> str:
    pieces: List[str] = []
    pieces.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">')
    if style == "editorial":
        pieces.append('<rect width="1400" height="2100" fill="#F5F1EA"/>')
        pieces.append(svg_ellipse(700, 1968, 255, 38, "#C8C0B4", 0.16))
        pieces.extend(build_body(style))
        halo = "#F6F2EA"
        fill = "#DE5A45"
        stroke = "#6D261C"
    else:
        pieces.append('<rect width="1400" height="2100" rx="40" fill="#F4F8F6"/>')
        pieces.append(svg_ellipse(700, 1968, 270, 44, "#BFCBC4", 0.18))
        pieces.extend(build_body(style))
        halo = "#FFFFFF"
        fill = "#F05B46"
        stroke = "#7B2B21"

    for name in ordered_names:
        x, y = marker_points[name]
        r = 8.2
        if any(token in name for token in ("Thumb", "Index", "Middle", "Ring", "Pinky")):
            r = 6.2
        pieces.append(svg_circle(x, y, r + 2.2, halo, opacity=0.96))
        pieces.append(svg_circle(x, y, r, fill, stroke, 1.8))

    pieces.append("</svg>")
    return "\n".join(pieces)


def main() -> None:
    marker_names = read_marker_names(CSV_PATH)
    marker_points = build_marker_layout()
    missing = [name for name in marker_names if name not in marker_points]
    if missing:
        raise RuntimeError(f"Missing manual placements for: {', '.join(missing)}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SVG_PATH.write_text(build_svg(marker_points, marker_names, "infographic"))
    EDITORIAL_SVG_PATH.write_text(build_svg(marker_points, marker_names, "editorial"))
    INFOGRAPHIC_SVG_PATH.write_text(build_svg(marker_points, marker_names, "infographic"))
    print(SVG_PATH)
    print(EDITORIAL_SVG_PATH)
    print(INFOGRAPHIC_SVG_PATH)
    print(f"marker_count={len(marker_names)}")


if __name__ == "__main__":
    main()
