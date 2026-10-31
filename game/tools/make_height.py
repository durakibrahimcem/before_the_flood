#!/usr/bin/env python3
"""Makes a placeholder salon painting and height image from the WhatsApp copy.

Red is object height, 0 to 2.5 metres. Green marks walls, whose height the shader computes.
Replace both with Ebru's files at full size when they arrive.
"""
import sys

import numpy as np
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
OX, OY, W, H = 8, 26, 960, 539
FULL = 2.5

Image.open(SRC).convert("RGB").crop((OX, OY, OX + W, OY + H)).resize((1920, 1080), Image.LANCZOS).save(f"{OUT}/salon.png")

floor_y = 285 - OY
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
metres = np.zeros((H, W), dtype=np.float32)
wall = (yy < floor_y).astype(np.float32)


def shape(points, value):
    global metres, wall
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([(x - OX, y - OY) for x, y in points], fill=255)
    inside = np.array(mask) > 0
    level = value(yy + OY) if callable(value) else np.full((H, W), float(value), dtype=np.float32)
    metres = np.where(inside, level, metres)
    wall = np.where(inside, 0.0, wall)


shape([(14, 287), (78, 287), (92, 345), (14, 350)], 0.02)
shape([(65, 375), (90, 345), (90, 330), (190, 325), (285, 340), (305, 345), (325, 390), (345, 435), (340, 502), (270, 502), (262, 440), (85, 440), (68, 447), (63, 400)], lambda y: np.clip((505 - y) * 0.0062, 0.1, 0.95))
shape([(90, 437), (250, 435), (268, 500), (70, 497)], 0.45)
shape([(640, 243), (915, 247), (910, 335), (640, 335)], lambda y: np.clip((338 - y) * 0.0098, 0.05, 0.92))
shape([(633, 240), (655, 217), (917, 217), (915, 247)], 0.95)
shape([(917, 165), (960, 165), (960, 425), (920, 425), (912, 390)], lambda y: np.clip((430 - y) * 0.0098, 0.05, 2.0))
shape([(545, 458), (570, 452), (583, 470), (570, 532), (600, 538), (552, 524)], 0.6)
shape([(860, 465), (890, 460), (897, 480), (880, 538), (835, 538)], 0.6)
shape([(600, 432), (832, 430), (878, 515), (553, 525)], 0.75)
shape([(688, 432), (695, 405), (720, 398), (745, 408), (747, 432)], 1.15)
shape([(682, 543), (685, 500), (720, 492), (750, 505), (757, 543)], 0.9)

rgb = np.zeros((H, W, 3), dtype=np.uint8)
rgb[..., 0] = np.clip(metres / FULL * 255, 0, 255).astype(np.uint8)
rgb[..., 1] = (wall * 255).astype(np.uint8)
Image.fromarray(rgb).resize((1920, 1080), Image.NEAREST).save(f"{OUT}/salon_height.png")
