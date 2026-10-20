import numpy as np
from PIL import Image
from scipy import ndimage

def isbg(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r < 45) & (g < 50) & (b < 90) & (b >= r)

def cut(path, box, pad=3, close=6):
    im = Image.open(path).convert('RGB')
    x0, y0, x1, y1 = box
    a = np.asarray(im.crop((x0 + pad, y0 + pad, x1 - pad, y1 - pad)))
    bgm = isbg(a)
    lab, n = ndimage.label(bgm)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    out = np.isin(lab, list(edge))
    alpha = np.where(out, 0, 255).astype(np.uint8)
    # drop small specks not connected to the main sprite
    fg = alpha > 0
    l2, n2 = ndimage.label(fg)
    if n2:
        sizes = ndimage.sum(fg, l2, range(1, n2 + 1))
        keep = np.isin(l2, [i + 1 for i, s in enumerate(sizes) if s >= max(30, sizes.max() * 0.02)])
        alpha = np.where(keep, alpha, 0).astype(np.uint8)
    # dark windows and doors that touch the outline: close the silhouette and fill it
    fg = alpha > 0
    if close:
        padded = np.pad(fg, close + 2)
        solid = ndimage.binary_fill_holes(ndimage.binary_closing(padded, iterations=close))[close + 2:-close - 2, close + 2:-close - 2]
        fg = solid & (fg | ~ndimage.binary_dilation(~solid, iterations=2))
    alpha = (ndimage.binary_erosion(fg, iterations=1) * 255).astype(np.uint8)
    rgba = np.dstack([a, alpha])
    img = Image.fromarray(rgba, 'RGBA')
    bb = img.getbbox()
    return img.crop(bb) if bb else img
