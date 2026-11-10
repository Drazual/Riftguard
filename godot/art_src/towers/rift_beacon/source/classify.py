import numpy as np
f=np.load('faces.npz'); c=f['c']; roots=np.load('vert_roots.npy'); rt=roots[f['fv']]
x,y,z=c.T; cz=0.1043; r=np.hypot(x,z-cz); a=np.degrees(np.arctan2(z-cz,x)); ay=np.abs(y)
cls=np.zeros(len(c),dtype=np.int8)  # 0 base,1 outer,2 inner,3 crystal
band=(np.abs(a)<16)|(np.abs(a)>164)
ring=(r>0.345)&(((ay<0.08)&(r<0.565))|(band&(ay<0.115)&(r<0.56)))
inner=ring&(r<0.432)&(ay<0.05)
cls[ring]=1; cls[inner]=2
crown=(np.abs(x)<0.2)&(z>cz+0.25); post=(np.abs(x)<0.14)&(z<cz-0.25)
for zone in (crown,post):
    cls[zone]=0
    cls[zone&(ay<0.072)&(r>0.432)&(r<0.56)]=1
    cls[zone&(ay<0.046)&(r<0.432)&(r>0.345)]=2
cls[(z>0.715)&(np.abs(x)<0.12)&(np.abs(y)<0.12)]=3
np.save('face_cls.npy',cls); print(np.bincount(cls))
