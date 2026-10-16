"""Original four-direction 64px creature sheets; no external assets/packages."""

import random
from build_pixel_art import Pixels, ROOT, actor_sheet


def creature(species, direction, frame):
    p = Pixels(64, 64)
    rng = random.Random(199 + direction)
    step = (0, -2, 2)[frame]
    if species == "lantern_moth":
        spread = (0, -5, 2)[frame]
        for side in (-1, 1):
            for y in range(8, 49):
                width = int(25 * (1 - abs(y - 26) / 30)) + spread
                x = 32 - width if side < 0 else 32
                p.rect(x, y, width, 1, "233942")
                p.rect(x + 2, y, max(1, width - 5), 1, "46616a")
                if y % 7 == 0:
                    p.rect(x + 4, y, max(1, width - 10), 1, "839587")
            p.ellipse(14 if side < 0 else 41, 21, 10, 14, "8d714e")
            p.ellipse(16 if side < 0 else 43, 24, 6, 8, "bca56b")
            p.ellipse(18 if side < 0 else 45, 26, 2, 4, "26343a")
        p.ellipse(27, 10, 11, 42, "263337")
        p.rect(29, 19, 7, 26, "59695e")
        for y in range(24, 48, 5):
            p.rect(30, y, 6, 2, "8b9681")
        p.ellipse(25, 7, 15, 14, "283b3f")
        p.rect(27, 11, 4, 3, "ebbd72")
        p.rect(34, 11, 4, 3, "ebbd72")
        for y in range(0, 9):
            p.dot(26 - y // 3, y, "97ab98")
            p.dot(38 + y // 3, y, "97ab98")
        for y in (31, 39, 47):
            p.rect(22, y, 7, 2, "738578")
            p.rect(36, y, 7, 2, "738578")
    else:
        wolf = species == "werewolf"
        base = "415762" if wolf else "51432e"
        mid = "71858a" if wolf else "88704b"
        light = "a8ada0" if wolf else "b39a68"
        # Long, articulated arms, oversized paws and layered fur silhouette.
        p.ellipse(15, 21, 35, 31, base)
        p.ellipse(20, 19, 26, 31, mid)
        p.ellipse(10, 23 + step, 11, 29, base)
        p.ellipse(45, 23 - step, 11, 29, base)
        p.rect(11, 46 + step, 10, 10, mid)
        p.rect(45, 46 - step, 10, 10, mid)
        for x, shift in ((21, step), (36, -step)):
            p.rect(x, 45 + shift, 9, 16, base)
            p.rect(x - 2, 57 + shift, 13, 6, mid)
            for claw in range(3):
                p.rect(x - 1 + claw * 4, 61 + shift, 2, 2, "d5c9a0")
        for _ in range(90):
            x, y = rng.randrange(16, 49), rng.randrange(24, 50)
            if p.data[y*64+x][3]:
                p.rect(x, y, 1, 3, rng.choice((base, light, mid)))
        if wolf:
            # Angular ears, long muzzle, ruff and individual fangs.
            for y in range(13):
                p.rect(19 + y//3, y+3, 5, 1, base)
                p.rect(40 - y//3, y+3, 5, 1, base)
            p.ellipse(19, 9, 27, 23, base)
            p.ellipse(23, 12, 21, 18, mid)
            p.ellipse(27, 20, 13, 13, light)
            p.rect(29, 21, 9, 4, "20363d")
            p.rect(26, 27, 15, 5, "35434a")
            for x in (28, 32, 37):
                p.rect(x, 27, 2, 3, "e5d8b4")
            p.rect(24, 16, 4, 2, "e5bc71")
            p.rect(37, 16, 4, 2, "e5bc71")
            for x in range(17, 49, 4):
                p.rect(x, 24 + abs(x-32)//3, 3, 5, light)
        else:
            p.ellipse(19, 3, 28, 29, base)
            p.ellipse(24, 10, 19, 20, mid)
            p.ellipse(26, 14, 15, 15, "b29c72")
            p.rect(26, 14, 5, 2, "293c34")
            p.rect(36, 14, 4, 2, "293c34")
            p.rect(29, 17, 8, 5, "655439")
            p.rect(28, 26, 11, 2, "5d4d34")
            p.ellipse(24, 4, 16, 9, "927852")
            for _ in range(24):
                p.rect(rng.randrange(21, 45), rng.randrange(4, 12), 1, 4, light)
    if direction == 1:
        # Back fur/wing veins obscure the face; all directions remain distinct.
        p.ellipse(22, 9, 22, 20, "2e4448" if species != "bigfoot" else "5b4c32")
        for y in range(13, 27, 4):
            p.rect(27, y, 11, 2, "5a7071" if species != "bigfoot" else "89714a")
    elif direction == 2:
        p.rect(21, 12, 8, 17, "33494e" if species != "bigfoot" else "5e4d31")
        if species == "werewolf":
            p.rect(38, 21, 12, 7, "a8ada0")
            p.rect(47, 21, 4, 4, "273b40")
    return p


if __name__ == "__main__":
    for species in ("werewolf", "bigfoot", "lantern_moth"):
        actor_sheet(species, lambda direction, frame, name=species: creature(name, direction, frame), 64, 64)
    print("Built original werewolf, Bigfoot and lantern-moth directional sheets.")
