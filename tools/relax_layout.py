#!/usr/bin/env python3
"""把 data/buildings.json 里的建筑“挤紧”：楼保持真实占地，只收窄楼与楼之间的距离。

做法：先把每栋楼的位置（相对十字街口）乘以 street_scale 压近，
再把互相重叠或贴得太近的楼沿最短方向推开，直到任意两栋之间至少留出 min_gap 米；
同时保证中央大街和十字街两条走廊不被楼占住。
结果写回每栋楼的 wx / wz（游戏里的世界坐标，米）。x / z 仍是索引图上的原始坐标，不动。

换了建筑数据、或者想调松紧，改下面两个参数后重新运行：
    python3 tools/relax_layout.py
"""
import json
import math
import pathlib

STREET_SCALE = 0.62   # 位置的压缩比例：越小街区越挤
MIN_GAP = 9.0         # 两栋楼之间至少留的距离（米）
AVENUE_HALF = 10.0    # 中央大街走廊的半宽（路面 + 两侧的行道树、路灯）
CROSS_NORTH = -15.0   # 十字街走廊的北沿（给架空供暖管留位置）
CROSS_SOUTH = 10.5    # 十字街走廊的南沿
ITERATIONS = 600

path = pathlib.Path(__file__).resolve().parent.parent / "data" / "buildings.json"
data = json.loads(path.read_text(encoding="utf8"))
ox, oz = data["origin"]
B = [dict(src=b, x=(b["x"] - ox) * STREET_SCALE, z=(b["z"] - oz) * STREET_SCALE,
          hl=b["len"] / 2, hw=b["wid"] / 2, a=math.radians(b["rot"])) for b in data["buildings"]]


def axes(b):
    ca, sa = math.cos(b["a"]), math.sin(b["a"])
    return [(ca, sa), (-sa, ca)]


def extent(b, ax, margin=0.0):
    (ux, uz), (vx, vz) = axes(b)
    return (b["hl"] + margin) * abs(ux * ax[0] + uz * ax[1]) + (b["hw"] + margin) * abs(vx * ax[0] + vz * ax[1])


def push_vector(a, b, margin):
    """两个带朝向的矩形（各自外扩 margin）重叠时，返回 (重叠量, 把 b 推离 a 的方向)。"""
    best = None
    for ax in axes(a) + axes(b):
        dist = (b["x"] - a["x"]) * ax[0] + (b["z"] - a["z"]) * ax[1]
        overlap = extent(a, ax, margin) + extent(b, ax, margin) - abs(dist)
        if overlap <= 0:
            return None
        if best is None or overlap < best[0]:
            best = (overlap, ax if dist >= 0 else (-ax[0], -ax[1]))
    return best


def same_group(a, b):
    # B075 和 B075b 是同一栋十字形的楼，本来就交叉
    return a["src"]["id"].rstrip("b") == b["src"]["id"].rstrip("b")


def keep_streets_clear(b):
    ex, ez = extent(b, (1, 0)), extent(b, (0, 1))
    if abs(b["x"]) - ex < AVENUE_HALF and -305 < b["z"] < 120:
        b["x"] = math.copysign(AVENUE_HALF + ex, b["x"] if b["x"] != 0 else 1)
    if b["z"] - ez < CROSS_SOUTH and b["z"] + ez > CROSS_NORTH and -125 - ex < b["x"] < 180 + ex:
        b["z"] = CROSS_SOUTH + ez if b["z"] > (CROSS_NORTH + CROSS_SOUTH) / 2 else CROSS_NORTH - ez


for it in range(ITERATIONS):
    moved = 0
    for i in range(len(B)):
        for j in range(i + 1, len(B)):
            if same_group(B[i], B[j]):
                continue
            r = push_vector(B[i], B[j], MIN_GAP / 2)
            if r and r[0] > 0.05:
                overlap, ax = r
                step = overlap * 0.5 * 0.5
                moved += 1
                B[i]["x"] -= ax[0] * step
                B[i]["z"] -= ax[1] * step
                B[j]["x"] += ax[0] * step
                B[j]["z"] += ax[1] * step
    for b in B:
        keep_streets_clear(b)
    if moved == 0:
        break

tight = sum(1 for i in range(len(B)) for j in range(i + 1, len(B))
            if not same_group(B[i], B[j]) and push_vector(B[i], B[j], MIN_GAP / 2 - 1.0))
for b in B:
    b["src"]["wx"] = round(b["x"], 2)
    b["src"]["wz"] = round(b["z"], 2)
data["street_scale"] = STREET_SCALE
data["min_gap"] = MIN_GAP
data["scale"] = 1.0

lines = ["{", ' "comment": %s,' % json.dumps(data["comment"], ensure_ascii=False),
         ' "origin": %s,' % json.dumps(data["origin"]),
         ' "scale": 1.0,', ' "street_scale": %s,' % STREET_SCALE, ' "min_gap": %s,' % MIN_GAP, ' "buildings": [']
rows = ["  " + json.dumps(b, ensure_ascii=False) for b in data["buildings"]]
lines.append(",\n".join(rows))
lines += [" ]", "}"]
path.write_text("\n".join(lines) + "\n", encoding="utf8")
xs = [b["x"] for b in B]
zs = [b["z"] for b in B]
print("iterations=%d, pairs closer than %.0f m: %d, extent x %.0f..%.0f z %.0f..%.0f"
      % (it + 1, MIN_GAP - 2.0, tight, min(xs), max(xs), min(zs), max(zs)))
