"""Original pixel art expansions using the project's native standard-library renderer."""
from build_pixel_art import Pixels, ROOT, actor_sheet, camper
from build_cryptids import forest_humanoid
import random

ROLES = ['jock','mechanic','scout','medic','quiet','quartermaster']
COLORS = ['547e9b','7c9190','67906b','c4b7a1','615884','bb924d']
def survivor(role, direction, frame):
    p = camper(direction, frame)
    accent = COLORS[ROLES.index(role)]
    p.rect(6,14,12,9,accent)
    for y in (15,19,22): p.rect(7,y,10,1,'dfc89b')
    p.rect(11,14,2,10,'34444b')
    p.rect(7,17,3,3,'354e50')
    p.dot(8,17,'ede2bd')
    if role == 'jock':
        p.rect(4,14,3,8,'ded4b4'); p.rect(17,14,3,8,'ded4b4')
        p.rect(8,17,2,4,'f8df9c')
    elif role == 'mechanic':
        p.rect(6,23,12,2,'4d4338'); p.rect(15,20,2,6,'b7c3ba')
        p.rect(14,20,4,2,'cbd5bd')
    elif role == 'scout':
        p.rect(5,13,3,10,'b8aa76'); p.rect(8,20,3,3,'d8ce9e')
        p.rect(17,17,4,6,'4d5e45')
    elif role == 'medic':
        p.rect(15,20,6,6,'dfd6b1'); p.rect(17,21,2,4,'a44d45'); p.rect(16,22,4,2,'a44d45')
    elif role == 'quiet':
        p.rect(7,3,10,4,'49435d'); p.rect(6,13,12,3,'8c819c')
    else:
        p.rect(3,14,4,11,'7d6843'); p.rect(17,14,4,11,'7d6843')
        for x in (4,18): p.rect(x,17,2,2,'e3c17f')
    if direction == 1:
        p.rect(7,14,10,10,'435545'); p.rect(8,15,8,2,accent)
        p.rect(8,20,8,3,'8e805a'); p.rect(9,19,2,1,'e1cfa3')
    return p

SPECIES = ['boiler_saint','bramble_seamstress','shutter_wraith','last_car_conductor','stoneback_ram','candle_grazer','switchback_hound']
def monster(kind,direction,frame):
    p=Pixels(64,64); step=(0,-2,2)[frame]
    palettes={'boiler_saint':('754d38','b28b54'),'bramble_seamstress':('3b5645','9fba76'),'shutter_wraith':('343a55','a7a6ba'),'last_car_conductor':('3b4e60','ac9764'),'stoneback_ram':('586367','acaf97'),'candle_grazer':('655b50','eacb86'),'switchback_hound':('604939','b1936b')}
    dark,light=palettes[kind]
    if kind in ('stoneback_ram','switchback_hound','candle_grazer'):
        p.ellipse(9,25,46,26,dark);p.ellipse(13,26,32,16,light)
        for x,k in ((12,step),(22,-step),(39,-step),(49,step)):
            p.rect(x,43+k,5,16,dark); p.rect(x-1,57+k,7,4,light)
        p.ellipse(18,13,28,23,dark);p.rect(23,27,18,9,light)
        for x in (19,41):
            for i in range(9): p.rect(x+(-i//2 if x==19 else i//2),16-i,3,3,light)
        if kind=='candle_grazer':
            for x in (24,33,41):
                p.rect(x,7,3,15,'d3c69e');p.ellipse(x-1,1+frame,5,8,'f2b266')
        elif kind=='switchback_hound':
            p.rect(22,31,23,4,'191f24')
            for x in range(24,44,4): p.rect(x,31,2,3,'ded4ad')
        else:
            for x,y in ((12,27),(23,21),(35,25),(44,32)): p.rect(x,y,9,8,'727e7a');p.rect(x+1,y,6,2,'c6bfa3')
    else:
        for y in range(22,56):
            half=10+(y-22)//5
            p.rect(32-half,y,half*2,1,dark); p.rect(34,y,half-4,1,light)
        p.rect(18,24+step,5,25,dark);p.rect(43,24-step,5,25,dark)
        p.rect(24,50+step,6,12,dark);p.rect(36,50-step,6,12,dark)
        p.rect(23,7,19,18,dark); p.rect(26,11,13,12,light)
        if kind=='boiler_saint':
            p.ellipse(20,23,25,28,'514d43');p.ellipse(24,27,17,17,'c19055')
            p.rect(29,32,8,9,'e7ae6c');p.rect(45,12,5,27,'b0a17e')
            for y in range(25,47,5): p.rect(22,y,21,1,'d0b07a')
        elif kind=='bramble_seamstress':
            for i in range(12):
                x=15+i*3; p.rect(x,16+i%3*3,2,7,'9caa78')
            p.rect(48,15,1,37,'e1dbba');p.rect(47,14,3,2,'eff3d4')
        elif kind=='shutter_wraith':
            p.rect(22,9,22,15,'202a35');p.ellipse(26,10,14,13,'859196');p.ellipse(29,13,8,7,'101c25')
            for y in range(30,59,4): p.rect(18,y,27,1,'7c7e9c')
        else:
            p.rect(20,7,25,5,'beab7a');p.rect(24,2,17,7,'3e5362')
            for y in (28,35,42): p.rect(32,y,2,2,'e1c67d')
            p.rect(45,43,9,13,'d5b36b');p.rect(47,45,5,8,'f2d7a1')
    if direction != 1:
        for x in (26,36):p.rect(x,19,3,2,'f8df9b')
    rng=random.Random(73+direction)
    for i in range(65):
        x,y=rng.randrange(10,54),rng.randrange(25,57)
        if p.data[y*64+x][3]:p.dot(x,y,light if i%3==0 else dark)
    return p

if __name__=='__main__':
    for role in ROLES:actor_sheet('survivor_'+role,lambda d,f: survivor(role,d,f),24,32)
    for kind in SPECIES:actor_sheet(kind,lambda d,f:monster(kind,d,f),64,64)
