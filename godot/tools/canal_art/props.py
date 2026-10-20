import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from cut import cut
from PIL import Image
P = {
 'lampA': ('furniture.png', (985, 52, 1055, 142)),
 'lampB': ('furniture.png', (1160, 52, 1280, 142)),
 'bollard': ('furniture.png', (1343, 72, 1385, 142)),
 'bench': ('furniture.png', (1283, 195, 1420, 262)),
 'trash': ('furniture.png', (258, 312, 322, 394)),
 'vendD': ('furniture.png', (238, 432, 332, 530)),
 'vendS': ('furniture.png', (423, 432, 518, 530)),
 'hydrant': ('furniture.png', (1168, 438, 1248, 530)),
 'atm': ('furniture.png', (976, 432, 1055, 530)),
 'palm': ('furniture.png', (893, 800, 1040, 885)),
 'flowers': ('furniture.png', (1072, 815, 1205, 885)),
 'hedge': ('furniture.png', (1255, 820, 1370, 885)),
 'tree': ('furniture.png', (45, 908, 130, 992)),
 'succulent': ('furniture.png', (205, 915, 280, 992)),
 'cafe': ('furniture.png', (333, 920, 472, 992)),
 'parasol': ('furniture.png', (520, 908, 610, 992)),
 'foodcart': ('furniture.png', (665, 908, 795, 992)),
 'sfountain': ('furniture.png', (705, 810, 820, 885)),
 'billboard': ('furniture.png', (378, 808, 498, 885)),
 'busstop': ('furniture.png', (1312, 688, 1510, 778)),
 'bikerack': ('furniture.png', (183, 820, 315, 885)),
 'ramen': ('vehicles.png', (28, 592, 265, 757)),
 'fruit': ('vehicles.png', (282, 592, 535, 757)),
 'hologram': ('vehicles.png', (795, 592, 980, 757)),
 'neonpalm': ('vehicles.png', (1018, 590, 1238, 757)),
 'watertank': ('vehicles.png', (1255, 590, 1510, 757)),
 'arcadem': ('vehicles.png', (552, 592, 775, 757)),
 'fountain': ('animated.png', (628, 628, 806, 738)),
 'coupeE': ('vehicles.png', (128, 128, 255, 222)),
 'sportE': ('vehicles.png', (378, 128, 498, 222)),
 'taxiE': ('vehicles.png', (622, 128, 755, 222)),
 'policeE': ('vehicles.png', (878, 128, 995, 222)),
 'coupeN': ('vehicles.png', (33, 112, 115, 258)),
 'sportN': ('vehicles.png', (283, 112, 365, 258)),
 'taxiN': ('vehicles.png', (527, 112, 610, 258)),
 'vanN': ('vehicles.png', (33, 328, 115, 468)),
 'vanE': ('vehicles.png', (130, 340, 255, 440)),
 'gate': ('streets.png', (625, 898, 765, 980)),
 'rift': ('streets.png', (925, 898, 1065, 980)),
 'scooterE': ('vehicles.png', (1120, 345, 1230, 425)),
 'neonsign': ('animated.png', (182, 100, 372, 190)),
}
if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))  # put the Neon City sheets here first
    sheet = Image.new('RGBA', (1600, 900), (80, 200, 80, 255))
    x = y = 0; rowh = 0
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    for k, (f, box) in P.items():
        close = 0 if k in ('gate', 'rift') else 6
        s = cut(f, box, close=close)
        s.save('spr/%s.png' % k)
        if x + s.width > 1600:
            x = 0; y += rowh + 14; rowh = 0
        sheet.alpha_composite(s, (x, y + 12)); d.text((x, y), k, fill=(0, 0, 0))
        x += s.width + 10; rowh = max(rowh, s.height)
    sheet.save('sheet2.png')
