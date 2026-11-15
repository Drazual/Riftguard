# Ocean Drive rebuilt in Coral Spiral's ground style: pale tiled plaza, navy road with pink neon edges and cyan arrows.
import json, numpy as np, sys
from PIL import Image, ImageFilter
D='/home/user/riftguard/godot/assets/maps/map1_miami/'
L=json.load(open(D+'layout.json'))
W,H=768,416
P=np.array(L['path'],float)
B=np.stack([P[:,0]*0.8,(40+0.75*P[:,1])*0.8],1) # board px
yy,xx=np.mgrid[0:H,0:W].astype(float); xx+=0.5; yy+=0.5
best=np.full((H,W),1e9); S=np.zeros((H,W)); N=np.zeros((H,W)); T=np.zeros((H,W,2))
cum=np.concatenate([[0],np.cumsum(np.linalg.norm(np.diff(B,axis=0),axis=1))])
for i in range(len(B)-1):
    a,b=B[i],B[i+1]; d=b-a; l=np.linalg.norm(d)
    if l<1e-6: continue
    u=d/l; t=np.clip(((xx-a[0])*u[0]+(yy-a[1])*u[1]),0,l)
    px=a[0]+u[0]*t; py=a[1]+u[1]*t
    dist=np.hypot(xx-px,yy-py)
    m=dist<best
    best[m]=dist[m]; S[m]=(cum[i]+t)[m]
    N[m]=((xx-a[0])*(-u[1])+(yy-a[1])*u[0])[m]
    T[m]=u
rng=np.random.default_rng(7)
# plaza: Coral's half-cell tiles (20 x 11.547 board px), a soft tint per tile and a darker grout line
TW,TH=40.0,40.0/np.sqrt(3)
U=xx/TW+yy/TH; V=xx/TW-yy/TH
iu,iv=np.floor(U).astype(int),np.floor(V).astype(int)
tints=np.array([(244,214,204),(241,211,201),(248,217,207),(247,216,206),(243,213,203),(245,214,205)])
h=((iu*73856093)^(iv*19349663))&0x7fffffff
img=tints[h%len(tints)].astype(float)
fu,fv=U-iu,V-iv
line=(np.minimum(fu,1-fu)*TH<0.5)|(np.minimum(fv,1-fv)*TH<0.5)
img[line]=(234,198,190)
# road
CORE,MAG,PINK=6.0,7.6,9.2
img[best<PINK]=(242,138,199)
img[best<MAG]=(105,57,105)
road=best<CORE
img[road]=(43,37,73)
sp=road&(rng.random((H,W))<0.10); img[sp]=(52,45,85)
sp=road&(rng.random((H,W))<0.06); img[sp]=(44,38,74)
CY=np.array((90,206,236)); CYD=np.array((61,73,115))
# dashes, with an arrow every 4th gap
s=S; n=N
per=12.0; k=np.floor(s/per); f=s-k*per
AK=5
dash=road&(np.abs(n)<0.9)&(f<5)
# arrow: head t in [0,5] (pointing along travel), shaft t in [-5,0]
# a whole arrow over two dash periods: a shaft and a V head (two slanted strokes), like Coral's
t=s-np.floor(s/(per*AK))*per*AK  # 0..per*AK; the arrow lives in the last period and the first
t=np.where(t>per*AK-per, t-per*AK, t)  # -per..per*? 
def dir_at(q):
    i=int(np.clip(np.searchsorted(cum,q)-1,0,len(B)-2)); d=B[i+1]-B[i]; return d/np.linalg.norm(d)
mid=np.round(s/(per*AK))  # which arrow slot a pixel belongs to
ok={}
for m in np.unique(mid[road]):
    c=m*per*AK; ok[m]=float(np.dot(dir_at(c-per-2),dir_at(c+9)))>0.999
straight=np.vectorize(lambda m: ok.get(m,False))(mid)
arrow=road&straight&(t>-per)&(t<7)&( ((t<4)&(np.abs(n)<0.9)) | ((t>=-1)&(np.abs(np.abs(n)-(6.0-t)*0.75)<0.9)&(np.abs(n)<4.2)&(t<6.5)) )
slot=road&straight&(t>-per)&(t<per)
img[dash&~slot]=CY
img[arrow]=CY
edge=road&~(dash|arrow)&(np.abs(n)<1.6)&((k%4!=0)&(f<5.5)|(k%4==0)&(t>-5.5)&(t<5.5)&(np.abs(n)<=(5.6-np.maximum(t,0))*0.85+0.7))
img=img.astype(np.uint8)
Image.fromarray(img).resize((W*2,H*2),Image.NEAREST).save(sys.argv[1] if len(sys.argv)>1 else D+'ground.png')
