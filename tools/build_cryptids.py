"""Original four-direction 64px creature sheets; no external assets/packages."""

import random
from build_pixel_art import Pixels, ROOT, actor_sheet


def sasquatch(direction, frame):
    p = Pixels(64, 64)
    rng = random.Random(420 + direction)
    step = (0, -2, 2)[frame]
    # Tall, hunched ape: narrow crested skull, sloping shoulders, long arms.
    for y in range(18, 48):
        half = 20 - max(0, y - 24) // 3
        p.rect(32-half, y, half*2, 1, "302f25")
        p.rect(35-half, y, half+7, 1, "65553b")
    for side, shift in ((0, step), (1, -step)):
        x = 8 if side == 0 else 47
        p.rect(x, 23+shift, 9, 23, "3b3829")
        p.rect(x-1, 42+shift, 10, 11, "65553b")
        for finger in range(4):
            p.rect(x-1+finger*3, 49+shift, 2, 7-finger%2, "93805a")
        leg = 20 if side == 0 else 35
        p.rect(leg, 45+shift, 10, 15, "403b2b")
        p.rect(leg-2, 57+shift, 15, 6, "7b6947")
        for toe in range(4):
            p.rect(leg-1+toe*3, 60+shift, 2, 2, "b09a6a")
    for y in range(1, 25):
        half = min(11, 3+y//2) if y < 12 else 11-(y-12)//4
        p.rect(32-half, y, half*2, 1, "49412e")
        p.rect(33-half, y, half, 1, "796446")
    for _ in range(125):
        x,y = rng.randrange(10,54),rng.randrange(17,51)
        if p.data[y*64+x][3]:
            p.rect(x,y,1,rng.randrange(2,5),rng.choice(("88744e","534831","302f25")))
    if direction != 1:
        p.rect(25,10,15,15,"867650")
        p.rect(24,11,17,3,"3c3827")
        p.rect(26,14,4,2,"172a25")
        p.rect(35,14,4,2,"172a25")
        p.rect(30,15,6,6,"514b32")
        p.rect(28,20,11,4,"b09a70")
        p.rect(28,23,10,2,"393a2a")
        if direction == 2:
            p.rect(23,10,9,15,"534831")
            p.rect(38,16,7,5,"99855c")
    else:
        for y in range(7,26,3):
            p.rect(25,y,12,2,"8b754e")
    return p


def forest_humanoid(species, direction, frame):
    p = Pixels(64,64)
    step = (0,-2,2)[frame]
    if species == "vampire":
        for y in range(17,57):
            half = 10+(y-17)//5
            p.rect(32-half,y,half*2,1,"1e2935")
            p.rect(34,y,max(1,half-3),1,"683b4d")
            if y%5==0: p.rect(20,y,4,2,"435064")
        p.rect(24,22,15,27,"88929a")
        p.rect(30,22,4,26,"26333d")
        for y in (27,35,43): p.dot(32,y,"cfad77")
        p.rect(20,23+step,6,25,"344254")
        p.rect(39,23-step,6,25,"4b3547")
        for x,shift in ((25,step),(35,-step)):
            p.rect(x,48+shift,5,14,"27333c")
            p.rect(x-1,59+shift,8,4,"53616a")
        p.rect(24,4,17,17,"27313c")
        p.rect(26,7,13,15,"c0c6b6")
        p.rect(29,5,5,6,"27313c")
        p.rect(27,12,3,2,"bd656c"); p.rect(35,12,3,2,"bd656c")
        p.rect(29,18,8,2,"6e4655")
        for x in (30,35): p.rect(x,18,1,3,"ede1bd")
        for y in range(17,26):
            p.rect(18+(y-17)//2,y,4,1,"825366")
            p.rect(42-(y-17)//2,y,4,1,"b0747b")
    elif species == "witch":
        for y in range(24,60):
            half=8+(y-24)//4
            p.rect(32-half,y,half*2,1,"40324d")
            p.rect(24,y,5,1,"65516e")
            p.rect(35,y,4,1,"79617b")
            if y%7==0: p.rect(29,y,7,2,"aa9567")
        p.rect(20,27+step,7,19,"68516a")
        p.rect(39,26-step,7,17,"57435e")
        p.rect(44,40-step,5,5,"a1aa7d")
        p.rect(25,60+step,6,3,"a8a281"); p.rect(35,60-step,7,3,"596651")
        p.rect(24,15,17,14,"9aa880")
        p.rect(24,17,3,14,"ccd0ac")
        p.rect(40,17,3,14,"777e68")
        p.rect(29,20,3,2,"293d39"); p.rect(36,20,3,2,"293d39")
        p.rect(34,22,9,3,"b6bd91")
        for y in range(2,17):
            half=2+y//2
            p.rect(30-half,y,half*2,1,"38423e")
            p.rect(30-half,y,3,1,"66715a")
        p.rect(16,16,33,4,"726f4f")
        p.rect(24,12,15,3,"aa885b")
        p.rect(51,23,3,39,"8a7651")
        p.ellipse(47,21,10,10,"b0a4cf")
        p.rect(50,24,4,4,"ead9e8")
    else:
        # Antlered briar revenant: twig limbs, exposed ribs, moss and root feet.
        for x,shift in ((18,step),(40,-step)):
            p.rect(x,25+shift,4,29,"63745a")
            p.rect(x-3,48+shift,7,3,"a09c78")
            p.rect(x+3,45-shift,4,16,"53654e")
            p.rect(x+1,59-shift,10,3,"8a9270")
        p.rect(27,23,10,27,"4c6455")
        for y in range(26,46,5):
            p.rect(23,y,19,2,"a1aa82")
            p.rect(30,y,3,4,"d0c8a0")
        for y in range(19):
            p.rect(31-min(8,y//2),y+9,min(16,y)*1,1,"a1a88c")
        p.rect(27,17,4,3,"354e47"); p.rect(35,17,4,3,"354e47")
        p.rect(30,23,6,4,"435b50")
        for side in (-1,1):
            for y in range(15):
                x=32+side*(9+(14-y)//2)
                p.rect(x,y,2,1,"b4b38c")
                if y%5==0: p.rect(x-3,y,8,2,"859377")
        for y in range(31,53,4): p.rect(37,y,5,3,"7f8c56")
    if direction == 1:
        p.rect(25,8,15,19,"40324d" if species=="witch" else "34434a")
    elif direction == 2:
        p.rect(24,10,8,15,"485044")
    return p


def creature(species, direction, frame):
    if species == "bigfoot":
        return sasquatch(direction,frame)
    if species in ("vampire","witch","briar_revenant"):
        return forest_humanoid(species,direction,frame)
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
    for species in ("werewolf", "bigfoot", "lantern_moth", "vampire", "witch", "briar_revenant"):
        actor_sheet(species, lambda direction, frame, name=species: creature(name, direction, frame), 64, 64)
    print("Built six original directional creature sheets.")
