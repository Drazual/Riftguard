"""Re-encodes a GLB's embedded textures as PNG at game size (Godot rejects the JPEG Blender writes; a ~25 px enemy
needs no 2k maps): colour 1024, normal and metal/rough 512.  python3 glb_textures.py in.glb out.glb"""
import json, struct, sys, io
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
SIZE = {'color': 1024}
data = open(src, 'rb').read()
jl = struct.unpack('<I', data[12:16])[0]; j = json.loads(data[20:20 + jl])
b0 = 20 + jl + 8; binc = data[b0:b0 + struct.unpack('<I', data[20 + jl:24 + jl])[0]]
views = j['bufferViews']; img_views = {im['bufferView']: im for im in j.get('images', [])}
out = bytearray()
for i, bv in enumerate(views):
    chunk = binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    if i in img_views:
        im = img_views[i]; size = next((v for k, v in SIZE.items() if k in im.get('name', '')), 512)
        pic = Image.open(io.BytesIO(chunk)).convert('RGB')
        if pic.size[0] > size: pic = pic.resize((size, size), Image.LANCZOS)
        buf = io.BytesIO(); pic.save(buf, 'PNG', optimize=True); chunk = buf.getvalue(); im['mimeType'] = 'image/png'
        print(im.get('name'), pic.size, len(chunk))
    while len(out) % 4: out += b'\0'
    bv['byteOffset'] = len(out); bv['byteLength'] = len(chunk); out += chunk
while len(out) % 4: out += b'\0'
j['buffers'][0]['byteLength'] = len(out)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(out), 0x004E4942) + bytes(out)
open(dst, 'wb').write(glb); print('wrote', dst, len(glb))
