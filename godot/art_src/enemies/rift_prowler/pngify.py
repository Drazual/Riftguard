# Re-encodes a GLB's embedded JPEG textures as PNG (Godot's JPEG decoder rejects the base colour Blender writes).
import json, struct, sys, io
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
data = open(src, 'rb').read()
jl = struct.unpack('<I', data[12:16])[0]
j = json.loads(data[20:20 + jl])
b0 = 20 + jl + 8
binc = data[b0:b0 + struct.unpack('<I', data[20 + jl:24 + jl])[0]]
views = j['bufferViews']
img_views = {im['bufferView']: im for im in j.get('images', [])}
out = bytearray()
for i, bv in enumerate(views):
    chunk = binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    if i in img_views and img_views[i].get('mimeType') == 'image/jpeg':
        buf = io.BytesIO(); Image.open(io.BytesIO(chunk)).convert('RGB').save(buf, 'PNG', optimize=True)
        chunk = buf.getvalue(); img_views[i]['mimeType'] = 'image/png'
    while len(out) % 4: out += b'\0'
    bv['byteOffset'] = len(out); bv['byteLength'] = len(chunk); out += chunk
while len(out) % 4: out += b'\0'
j['buffers'][0]['byteLength'] = len(out)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(out), 0x004E4942) + bytes(out)
open(dst, 'wb').write(glb)
print('wrote', dst, len(glb))
