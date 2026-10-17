"""Rebuild original, pixel-aligned game art. Python standard library only."""

from pathlib import Path
import random
import sys
import struct
import zlib

ROOT = Path(__file__).resolve().parent.parent / "assets"
SPRITECOOK_OWNED = {"pine_0", "pine_1", "pine_2", "birch", "shrub", "boulder", "stalker", "camper",
    "survivor_jock", "survivor_mechanic", "survivor_scout", "survivor_medic", "survivor_quiet", "survivor_quartermaster",
    "werewolf", "bigfoot", "vampire", "witch", "briar_revenant", "lantern_moth", "switchback_hound", "relay_jackal",
    "ration_moth", "lens_eater", "boiler_saint", "shutter_wraith", "bramble_seamstress", "last_car_conductor",
    "stoneback_ram", "candle_grazer"}


def rgba(color):
    return tuple(bytes.fromhex(color)) + (255,) if isinstance(color, str) else color


class Pixels:
    def __init__(self, width, height):
        self.w, self.h = width, height
        self.data = [(0, 0, 0, 0)] * (width * height)

    def dot(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.data[y * self.w + x] = rgba(color)

    def rect(self, x, y, w, h, color):
        for row in range(y, y + h):
            for col in range(x, x + w):
                self.dot(col, row, color)

    def ellipse(self, x, y, w, h, color):
        for row in range(y, y + h):
            for col in range(x, x + w):
                if ((col + .5 - x - w / 2) / (w / 2)) ** 2 + ((row + .5 - y - h / 2) / (h / 2)) ** 2 <= 1:
                    self.dot(col, row, color)

    def paste(self, other, x, y, mirror=False):
        for row in range(other.h):
            for col in range(other.w):
                color = other.data[row * other.w + col]
                if color[3]:
                    self.dot(x + (other.w - col - 1 if mirror else col), y + row, color)

    def save(self, path):
        # These sprites are now SpriteCook art (see assets/README.md); keep them
        # unless --procedural is passed, so a rebuild never breaks the 40x48 stalker.
        if Path(path).stem in SPRITECOOK_OWNED and "--procedural" not in sys.argv:
            print("keeping SpriteCook art:", Path(path).name)
            return
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        scan = b"".join(b"\0" + bytes(c for pixel in self.data[y*self.w:(y+1)*self.w] for c in pixel) for y in range(self.h))
        data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        data += chunk(b"IDAT", zlib.compress(scan, 9)) + chunk(b"IEND", b"")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def camper(direction, frame):
    p = Pixels(24, 32)
    step = (0, -1, 1)[frame]
    # Hiking boots, socks, bare calves, cuffed shorts, plaid overshirt.
    for x, shift in ((7, step), (13, -step)):
        p.rect(x, 25 + shift, 4, 5, "bf9a70")
        p.rect(x, 28 + shift, 4, 2, "c9c6a0")
        p.rect(x - 1, 30 + shift, 6, 2, "202b30")
        p.rect(x, 30 + shift, 3, 1, "695a42")
    p.rect(6, 22, 12, 5, "8c8456")
    p.rect(11, 24, 2, 4, "4b5542")
    p.rect(5, 14, 14, 10, "974f3c")
    p.rect(7, 14, 10, 9, "bd784e")
    for y in (16, 20):
        p.rect(6, y, 12, 1, "df9e63")
        p.rect(9, y - 1, 1, 3, "8b4e39")
        p.rect(15, y - 1, 1, 3, "8b4e39")
    p.rect(3, 16 + step, 3, 7, "9b5f42")
    p.rect(3, 22 + step, 3, 3, "d4ae7e")
    p.rect(18, 16 - step, 3, 7, "ad6d47")
    p.rect(18, 22 - step, 3, 3, "e3c08e")
    p.rect(9, 12, 6, 3, "bd9368")
    p.rect(7, 5, 10, 8, "634b35")
    p.rect(8, 7, 8, 6, "dfbb8c")
    p.rect(9, 8, 6, 3, "eccb9d")
    p.rect(7, 3, 10, 4, "3e6256")
    p.rect(9, 2, 6, 2, "638775")
    if direction == 0:  # front
        p.rect(7, 6, 12, 2, "355247")
        p.dot(9, 9, "3a3730")
        p.dot(14, 9, "3a3730")
        p.rect(11, 12, 3, 1, "ac7d5c")
        p.rect(7, 14, 2, 9, "3e5c51")
        p.rect(15, 14, 2, 9, "3e5c51")
        p.rect(19, 22 - step, 3, 4, "293b3b")
        p.dot(20, 25 - step, "f8df9c")
    elif direction == 1:  # back: large pack and rolled sleeping mat
        p.rect(8, 7, 8, 6, "614934")
        p.rect(7, 3, 10, 5, "456f60")
        p.rect(7, 14, 10, 10, "264d4b")
        p.rect(8, 15, 8, 7, "48766a")
        p.rect(8, 19, 8, 1, "6b9c83")
        p.rect(10, 20, 4, 4, "2a4f4b")
        p.rect(5, 13, 14, 3, "b4a579")
        p.rect(6, 13, 1, 3, "716849")
        p.rect(16, 13, 1, 3, "716849")
    else:  # right; left is mirrored in the sheet
        p.rect(7, 14, 5, 10, "2c5551")
        p.rect(6, 13, 5, 3, "b7a77c")
        p.rect(12, 7, 5, 6, "dfbb8c")
        p.dot(16, 9, "37342c")
        p.rect(13, 6, 7, 2, "355247")
        p.rect(18, 21 - step, 4, 3, "283b3a")
        p.dot(21, 22 - step, "ffe3a2")
    return p


def stalker(direction, frame):
    p = Pixels(32, 40)
    step = (0, -1, 1)[frame]
    for x, shift in ((9, step), (19, -step)):
        p.rect(x, 31 + shift, 5, 7, "263133")
        p.rect(x - 1, 36 + shift, 7, 3, "17272a")
        p.rect(x, 36 + shift, 4, 1, "4d5146")
    p.rect(7, 16, 19, 17, "303f3b")
    p.rect(9, 16, 15, 16, "4d5846")
    p.rect(11, 17, 5, 14, "62705a")
    p.rect(7, 31, 5, 3, "34443d")
    p.rect(20, 31, 6, 4, "34443d")
    p.rect(15, 16, 2, 17, "283a35")
    for y in (19, 24, 29):
        p.dot(17, y, "a59369")
    p.rect(9, 24, 5, 4, "354a40")
    p.rect(19, 24, 5, 4, "354a40")
    p.rect(3, 18 + step, 5, 12, "34443c")
    p.rect(25, 17 - step, 4, 13, "485341")
    p.rect(4, 29 + step, 4, 4, "8d8872")
    p.rect(25, 29 - step, 4, 4, "aaa086")
    # Chipped steel logging hook, unlike a franchise mask/weapon silhouette.
    p.rect(28, 26 - step, 2, 11, "65523b")
    p.rect(28, 24 - step, 4, 7, "919b92")
    p.rect(30, 25 - step, 2, 3, "c6c6ae")
    p.rect(28, 29 - step, 2, 2, "82634b")
    p.rect(7, 5, 19, 12, "253a36")
    p.rect(10, 2, 13, 16, "3d5144")
    p.rect(12, 3, 8, 2, "62705a")
    p.rect(12, 6, 10, 10, "b0a78a")
    p.rect(13, 7, 8, 7, "d1c7a5")
    if direction == 1:
        p.rect(10, 5, 13, 13, "43594a")
        p.rect(12, 4, 4, 10, "586d55")
        p.rect(14, 17, 4, 16, "3a4c40")
    elif direction == 0:
        p.rect(13, 9, 3, 2, "25312e")
        p.rect(19, 10, 2, 1, "25312e")
        for y in (7, 10, 13):
            p.dot(17, y, "7f7963")
        p.rect(14, 15, 6, 1, "7e7963")
    else:
        p.rect(10, 5, 7, 12, "3e5446")
        p.rect(18, 7, 6, 8, "c8bd9c")
        p.rect(21, 10, 3, 1, "273832")
    return p


def actor_sheet(name, painter, width, height):
    sheet = Pixels(width * 3, height * 4)
    for row, direction in enumerate((0, 1, 2, 2)):
        for frame in range(3):
            sheet.paste(painter(direction, frame), frame * width, row * height, mirror=row == 3)
    sheet.save(ROOT / "sprites" / (name + ".png"))


def terrain():
    atlas = Pixels(128, 64)
    palettes = [
        ["354a36", "394f38", "304733", "3d523a", "79684e", "816f52", "74634a", "78796a"],
        ["344c3e", "3c5542", "534e37", "5c5139", "8b7c61", "938369", "9b9a80", "939984"],
        ["243e4b", "284653", "385866", "456775", "615444", "705b46", "6f5342", "786249"],
        ["5d5742", "686049", "7b7866", "89846e", "907d57", "a08b60", "4d6246", "586b46"],
    ]
    rng = random.Random(822)
    for row in range(4):
        for col in range(8):
            base = tuple(bytes.fromhex(palettes[row][col]))
            for y in range(16):
                for x in range(16):
                    n = rng.choice((-8, -3, 0, 0, 2, 5, 8))
                    color = tuple(max(0, min(255, c+n)) for c in base) + (255,)
                    atlas.dot(col*16+x, row*16+y, color)
            if row == 0 and col < 4 or row == 1 and col < 4:
                for _ in range(8):
                    x, y = rng.randrange(14), rng.randrange(14)
                    atlas.rect(col*16+x, row*16+y, 1, 2, "567049" if col < 2 else "6c6545")
            elif row == 1 and col in (4, 5) or row == 3 and col in (4, 5):
                for x in (0, 8):
                    atlas.rect(col*16+x, row*16, 1, 16, "605c47")
                    atlas.rect(col*16+x+2, row*16+2, 1, 10, "a09471")
                atlas.rect(col*16+1, row*16+3, 7, 1, "6d644e")
                atlas.rect(col*16+9, row*16+12, 7, 1, "6d644e")
                atlas.dot(col*16+6, row*16+5, "c1b28a")
            elif row == 1 and col in (6, 7):
                atlas.rect(col*16, row*16+7, 16, 1, "68756d")
                atlas.rect(col*16+7, row*16, 1, 16, "68756d")
            elif row == 2 and col < 4:
                for _ in range(5):
                    x, y = rng.randrange(12), rng.randrange(16)
                    atlas.rect(col*16+x, row*16+y, 3, 1, "537c87" if col > 1 else "365763")
            elif row == 2:
                for y in (0, 5, 10, 15):
                    atlas.rect(col*16, row*16+y, 16, 1, "443f36")
                    atlas.rect(col*16+(y%3)*4, row*16+y, 1, 5, "514737")
    atlas.save(ROOT / "tiles" / "camp_tiles.png")


def tree(name, seed, birch=False):
    rng = random.Random(seed)
    p = Pixels(64, 80)
    p.ellipse(12, 66, 40, 12, (10, 25, 23, 100))
    p.rect(29, 42, 7, 31, "80735a" if birch else "554333")
    p.rect(29, 43, 2, 30, "afa58a" if birch else "7f6644")
    for y in range(48, 73, 6):
        p.rect(29, y, rng.randrange(2, 5), 2, "514e3c")
    if birch:
        for x, y, w, h in ((8, 20, 42, 30), (20, 6, 35, 38), (24, 31, 36, 28)):
            p.ellipse(x, y, w, h, "223c32")
            p.ellipse(x+2, y+1, w-5, h-7, "42624a")
            p.ellipse(x+4, y+3, w-13, h-16, "66815a")
        for _ in range(50):
            p.rect(rng.randrange(12, 54), rng.randrange(15, 53), 2, 1, rng.choice(("819267", "54744e", "3b593d")))
    else:
        for top, height, width in ((3, 26, 24), (16, 30, 38), (30, 34, 54)):
            for y in range(height):
                span = int(width * y / height / 2)
                if y % 5 == 4:
                    span += 3
                p.rect(32-span, top+y, span*2+1, 1, "162f2b")
                if span > 3:
                    p.rect(32-span+2, top+y, span, 1, "345343")
                    if y % 4 in (1, 2):
                        p.rect(32-span+3, top+y, max(1, span-3), 1, "4b6e50")
            for _ in range(12):
                y = rng.randrange(top+height//2, top+height)
                span = int(width*(y-top)/height/2)
                p.rect(rng.randrange(32-span, 33), y, rng.randrange(2, 5), 1, "69815a")
    p.save(ROOT / "sprites" / (name + ".png"))


def ground_props():
    rock = Pixels(32, 24)
    rock.ellipse(1, 10, 30, 13, (10, 25, 23, 110))
    rock.ellipse(3, 3, 25, 18, "4c594f")
    rock.ellipse(5, 3, 19, 13, "798274")
    rock.ellipse(7, 3, 13, 8, "9ba18a")
    rock.rect(8, 15, 9, 3, "586d46")
    rock.rect(17, 12, 7, 2, "69804c")
    rock.save(ROOT / "sprites" / "boulder.png")
    shrub = Pixels(32, 24)
    for x, y, r in ((2, 12, 14), (9, 6, 15), (18, 11, 13)):
        shrub.ellipse(x, y, r, 10, "294b36")
        shrub.ellipse(x+1, y, r-3, 6, "527247")
    for x, y in ((5, 14), (14, 8), (22, 14)):
        shrub.rect(x, y, 2, 2, "aa8061")
    shrub.save(ROOT / "sprites" / "shrub.png")


if __name__ == "__main__":
    terrain()
    actor_sheet("camper", camper, 24, 32)
    actor_sheet("stalker", stalker, 32, 40)
    for i in range(3):
        tree("pine_" + str(i), 37 + i)
    tree("birch", 53, True)
    ground_props()
    print("Built original terrain atlas, directional character sheets, trees and props.")
