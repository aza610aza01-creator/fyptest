import argparse, math, time, urllib.request
from pathlib import Path
from dataclasses import dataclass, field
import cv2, numpy as np, mediapipe as mp, mss, win32gui

MODEL='pose_landmarker_full.task'
URL='https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task'
EXERCISES=['squat','push_up','bicep_curl','shoulder_press','lateral_raise','front_raise','lunge','sit_up','leg_raise','glute_bridge','jumping_jack','mountain_climber','plank','deadlift']
LS,RS,LE,RE,LW,RW,LH,RH,LK,RK,LA,RA,LF,RF=11,12,13,14,15,16,23,24,25,26,27,28,31,32
CON=[(0,2),(0,5),(2,7),(5,8),(11,12),(11,13),(13,15),(12,14),(14,16),(11,23),(12,24),(23,24),(23,25),(25,27),(27,29),(29,31),(27,31),(24,26),(26,28),(28,30),(30,32),(28,32)]
CYC={'squat':('DOWN','UP'),'push_up':('DOWN','UP'),'bicep_curl':('CONTRACTED','EXTENDED'),'shoulder_press':('UP','DOWN'),'lateral_raise':('UP','DOWN'),'front_raise':('UP','DOWN'),'lunge':('DOWN','UP'),'sit_up':('UP','DOWN'),'leg_raise':('UP','DOWN'),'glute_bridge':('UP','DOWN'),'jumping_jack':('OPEN','CLOSED'),'mountain_climber':('LEFT','RIGHT'),'deadlift':('DOWN','UP')}

class LP:
 def __init__(s):s.v=None
 def f(s,x,a):s.v=x if s.v is None else a*x+(1-a)*s.v;return s.v
class Euro:
 def __init__(s):s.x=LP();s.d=LP();s.t=None
 def f(s,x,t):
  dt=1/30 if s.t is None else max(t-s.t,.001);s.t=t;old=x if s.x.v is None else s.x.v;dx=(x-old)/dt;ad=1/(1+1/(2*math.pi*dt));ed=s.d.f(dx,ad);cut=1.2+.025*abs(ed);a=1/(1+1/(2*math.pi*cut*dt));return s.x.f(x,a)
@dataclass
class State:
 filt:list=field(default_factory=lambda:[[Euro(),Euro(),Euro()] for _ in range(33)]);phase:str='UNKNOWN';cand:object=None;frames:int=0;start:bool=False;reps:int=0;hold:float=0;last:object=None
 def reset(s):s.filt=[[Euro(),Euro(),Euro()] for _ in range(33)];s.phase='UNKNOWN';s.cand=None;s.frames=0;s.start=False;s.reps=0;s.hold=0;s.last=None;s.push_prev=None;s.descent_started=None;s.front_hand_ratio=None

def ok(p,*ids):return all(not np.isnan(p[i]).any() for i in ids)
def angle(a,b,c):
 if any(np.isnan(x).any() for x in(a,b,c)):return None
 u,v=a-b,c-b;d=np.linalg.norm(u)*np.linalg.norm(v);return None if d<1e-8 else math.degrees(math.acos(np.clip(float(np.dot(u,v)/d),-1,1)))
def dist(a,b):return None if np.isnan(a).any() or np.isnan(b).any() else float(np.linalg.norm(a-b))
def mid(a,b):return np.array([np.nan]*3) if np.isnan(a).any() or np.isnan(b).any() else(a+b)/2
def side(p,q,l,r):return ('left',l) if (np.mean(q[list(l)]) if ok(p,*l) else -1)>=(np.mean(q[list(r)]) if ok(p,*r) else -1) else('right',r)

def pushup_fullbody(p,q):
 # Select one coherent side for arm and body checks.
 arm_side,arm_ids=side(p,q,(LS,LE,LW),(RS,RE,RW))
 if arm_side=='left': sh,el,wr,hip,knee,ankle=LS,LE,LW,LH,LK,LA
 else: sh,el,wr,hip,knee,ankle=RS,RE,RW,RH,RK,RA
 required=(sh,el,wr,hip,knee,ankle)
 if not ok(p,*required):
  return None,arm_side,required,None,None,'FULL BODY NOT VISIBLE',False
 elbow=angle(p[sh],p[el],p[wr])
 body=angle(p[sh],p[hip],p[ankle])
 knee_angle=angle(p[hip],p[knee],p[ankle])
 upper=dist(p[sh],p[el]);fore=dist(p[el],p[wr]);torso=dist(p[sh],p[hip]);leg=dist(p[hip],p[ankle])
 arm_ok=(upper is not None and fore is not None and .45<=upper/max(fore,1e-6)<=2.2)
 proportions_ok=(torso is not None and leg is not None and .35<=torso/max(leg,1e-6)<=1.35)
 body_ok=body is not None and body>=150
 knees_ok=knee_angle is not None and knee_angle>=150
 quality_ok=arm_ok and proportions_ok and body_ok and knees_ok
 if not arm_ok: feedback='ARM TRACKING UNRELIABLE'
 elif not proportions_ok: feedback='MOVE SIDE-ON / SHOW FULL BODY'
 elif body is not None and body<150: feedback='KEEP SHOULDER-HIP-ANKLE STRAIGHT'
 elif knee_angle is not None and knee_angle<150: feedback='KEEP LEGS STRAIGHT'
 else: feedback='FULL-BODY FORM OK'
 return elbow,arm_side,required,body,knee_angle,feedback,quality_ok

def pushup_bilateral(p,q):
 required=(LS,LE,LW,RS,RE,RW)
 if not ok(p,*required):return None,'BOTH SHOULDERS, ELBOWS AND WRISTS MUST BE VISIBLE',False
 le=angle(p[LS],p[LE],p[LW]);re=angle(p[RS],p[RE],p[RW])
 if le is None or re is None:return None,'BILATERAL ARM LANDMARKS UNRELIABLE',False
 sw=dist(p[LS],p[RS]);ww=dist(p[LW],p[RW]);ratio=None if not sw or ww is None else ww/sw
 lf=vector_angle(p[LE]-p[LS],p[RS]-p[LS]);rf=vector_angle(p[RE]-p[RS],p[LS]-p[RS])
 hand_ok=ratio is not None and .80<=ratio<=1.75
 flare_ok=lf is not None and rf is not None and 20<=lf<=80 and 20<=rf<=80
 symmetry_ok=abs(le-re)<=20
 valid=hand_ok and flare_ok and symmetry_ok
 if not hand_ok:feedback='ADJUST HAND WIDTH'
 elif not flare_ok:feedback='KEEP BOTH ELBOWS CONTROLLED'
 elif not symmetry_ok:feedback='ASYMMETRIC ARM POSITION'
 else:feedback='FRONT UPPER-BODY FORM OK'
 return (le+re)/2,feedback,valid


def vector_angle(u,v):
 d=np.linalg.norm(u)*np.linalg.norm(v)
 return None if d<1e-8 else math.degrees(math.acos(np.clip(float(np.dot(u,v)/d),-1,1)))

def pushup_rules(p,q,scr,state,mode,now):
 # Strict mode validates both sides. Standard mode counts from one coherent side.
 if mode=='front':
  # Front view counts from bilateral elbow motion. Hand width and flare are
  # coaching warnings only because perspective changes them during descent.
  required=(LS,LE,LW,RS,RE,RW)
  if not ok(p,*required):return None,'BOTH ARMS MUST BE VISIBLE',False,{}
  le=angle(p[LS],p[LE],p[LW]);re=angle(p[RS],p[RE],p[RW])
  if le is None or re is None:return None,'BILATERAL ARM LANDMARKS UNRELIABLE',False,{}
  elbow=(le+re)/2;elbow_diff=abs(le-re)
  metrics={'elbow':elbow,'body':None,'knee':None,'flare':None,'hand_ratio':None}
  hand_ratio=None
  if not np.isnan(scr[[LS,RS,LW,RW]]).any():
   shoulder_px=float(np.linalg.norm(scr[LS]-scr[RS]));wrist_px=float(np.linalg.norm(scr[LW]-scr[RW]))
   if shoulder_px>1:hand_ratio=wrist_px/shoulder_px;metrics['hand_ratio']=hand_ratio
  lf=vector_angle(p[LE]-p[LS],p[RS]-p[LS]);rf=vector_angle(p[RE]-p[RS],p[LS]-p[RS])
  if lf is not None and rf is not None:metrics['flare']=max(lf,rf)
  phase=('DOWN' if elbow<105 else 'UP' if elbow>150 else None)
  symmetry_ok=elbow_diff<=30
  # Calibrate width only at UP. Never block DOWN/UP transitions with width.
  if phase=='UP' and hand_ratio is not None:
   old=getattr(state,'front_hand_ratio',None)
   state.front_hand_ratio=hand_ratio if old is None else .15*hand_ratio+.85*old
  if not symmetry_ok:feedback='ASYMMETRIC ARM POSITION'
  elif phase=='UP' and hand_ratio is not None and not (.55<=hand_ratio<=2.30):feedback='ADJUST HAND WIDTH AT TOP POSITION'
  elif metrics['flare'] is not None and metrics['flare']>90:feedback='KEEP BOTH ELBOWS CONTROLLED'
  else:feedback='FRONT UPPER-BODY FORM OK'
  # Only visibility and severe left/right mismatch stop counting.
  valid=symmetry_ok
  return (phase if valid else None),feedback,valid,metrics
 else:
  chosen,ids=side(p,q,(LS,LE,LW,LH,LK,LA),(RS,RE,RW,RH,RK,RA))
  if not ok(p,*ids):return None,'FULL BODY NOT VISIBLE',False,{}
  sides=[ids]

 elbows=[];bodies=[];knees=[];flares=[]
 for sh,el,wr,hip,knee,ankle in sides:
  elbows.append(angle(p[sh],p[el],p[wr]))
  bodies.append(angle(p[sh],p[hip],p[ankle]))
  knees.append(angle(p[hip],p[knee],p[ankle]))
  f=vector_angle(p[el]-p[sh],p[hip]-p[sh]);flares.append(f)
 if any(v is None for v in elbows+bodies+knees+flares):return None,'LANDMARKS UNRELIABLE',False,{}

 elbow=sum(elbows)/len(elbows);body=min(bodies);knee=min(knees);flare=max(flares)
 symmetry_ok=(len(elbows)==1 or abs(elbows[0]-elbows[1])<=20)
 body_ok=body>=150;knee_ok=knee>=150;flare_ok=20<=flare<=75

 hand_ratio=None;hand_ok=True
 if ok(p,LW,RW,LS,RS):
  sw=dist(p[LS],p[RS]);ww=dist(p[LW],p[RW])
  if sw and ww:hand_ratio=ww/sw;hand_ok=.80<=hand_ratio<=1.75
 elif mode=='strict':hand_ok=False

 # Temporal measures: movement, descent control, head-only motion and shoulder/hip sync.
 shoulder_scr=np.mean([scr[s[0]] for s in sides],axis=0)
 hip_scr=np.mean([scr[s[3]] for s in sides],axis=0)
 nose_scr=scr[0] if not np.isnan(scr[0]).any() else None
 prev=getattr(state,'push_prev',None)
 descent_ok=True;sync_ok=True;head_ok=True
 if prev:
  dt=max(now-prev['t'],1e-3);de=elbow-prev['elbow']
  shoulder_d=float(shoulder_scr[1]-prev['shoulder_y']);hip_d=float(hip_scr[1]-prev['hip_y'])
  scale=max(abs(float(shoulder_scr[1]-hip_scr[1])),20.0)
  sync_ok=abs(shoulder_d-hip_d)/scale<=.18
  if nose_scr is not None and prev.get('nose_y') is not None:
   nose_d=float(nose_scr[1]-prev['nose_y']);head_ok=not(abs(nose_d)>max(abs(shoulder_d)*2.2,scale*.10) and abs(shoulder_d)<scale*.05)
  if prev['elbow']>=145 and elbow<145:setattr(state,'descent_started',now)
  if elbow<=105:
   started=getattr(state,'descent_started',None);descent_ok=started is None or now-started>=.25
 state.push_prev={'t':now,'elbow':elbow,'shoulder_y':float(shoulder_scr[1]),'hip_y':float(hip_scr[1]),'nose_y':None if nose_scr is None else float(nose_scr[1])}

 valid=body_ok and knee_ok and flare_ok and hand_ok and symmetry_ok and descent_ok and sync_ok and head_ok
 if not hand_ok:feedback='ADJUST HAND WIDTH'
 elif not flare_ok:feedback='KEEP ELBOWS ABOUT 45 DEGREES'
 elif not symmetry_ok:feedback='ASYMMETRIC ARM POSITION'
 elif not body_ok:feedback='KEEP SHOULDER-HIP-ANKLE STRAIGHT'
 elif not knee_ok:feedback='KEEP LEGS STRAIGHT'
 elif not sync_ok:feedback='MOVE CHEST AND HIPS TOGETHER'
 elif not head_ok:feedback='DO NOT NOD THE HEAD FOR DEPTH'
 elif not descent_ok:feedback='CONTROL THE DESCENT'
 elif mode=='side':feedback='REP COUNT AVAILABLE | FULL BILATERAL CHECK UNAVAILABLE'
 else:feedback='STRICT FULL-BODY FORM OK'
 phase=('DOWN' if elbow<100 else 'UP' if elbow>155 else None)
 metrics={'elbow':elbow,'body':body,'knee':knee,'flare':flare,'hand_ratio':hand_ratio}
 return (phase if valid else None),feedback,valid,metrics

def profile(e,p,q,mode='standard'):
 if e=='squat':s,(a,b,c)=side(p,q,(LH,LK,LA),(RH,RK,RA));v=angle(p[a],p[b],p[c]);return('DOWN' if v and v<100 else 'UP' if v and v>155 else None),v,'knee'
 if e=='push_up':
  if mode=='strict':
   v,feedback,form_ok=pushup_bilateral(p,q)
  else:
   v,s,ids,body,knee,feedback,form_ok=pushup_fullbody(p,q)
  phase=('DOWN' if v and v<100 else 'UP' if v and v>155 else None)
  return (phase if form_ok else None),v,'elbow'
 if e=='bicep_curl':s,(a,b,c)=side(p,q,(LS,LE,LW),(RS,RE,RW));v=angle(p[a],p[b],p[c]);return('CONTRACTED' if v and v<60 else 'EXTENDED' if v and v>145 else None),v,'elbow'
 if e=='shoulder_press':s,(a,b,c)=side(p,q,(LS,LE,LW),(RS,RE,RW));v=angle(p[a],p[b],p[c]);return('UP' if v and v>145 and p[c][1]<p[a][1] else 'DOWN' if v and v<110 else None),v,'elbow'
 if e in('lateral_raise','front_raise'):
  s,(a,b,c)=side(p,q,(LH,LS,LE),(RH,RS,RE));v=angle(p[a],p[b],p[c]);return('UP' if v and v>75 else 'DOWN' if v and v<25 else None),v,'shoulder'
 if e=='lunge':
  x=angle(p[LH],p[LK],p[LA]);y=angle(p[RH],p[RK],p[RA]);z=[v for v in(x,y)if v];v=min(z)if z else None;return('DOWN' if v and v<110 else 'UP' if v and v>155 else None),v,'knee'
 if e in('sit_up','leg_raise','glute_bridge','deadlift'):
  s,(sh,h,k,a)=side(p,q,(LS,LH,LK,LA),(RS,RH,RK,RA));v=angle(p[sh],p[h],p[a] if e=='leg_raise' else p[k])
  if e=='sit_up':ph='UP' if v and v<80 else 'DOWN' if v and v>120 else None
  elif e=='leg_raise':ph='UP' if v and v<120 else 'DOWN' if v and v>150 else None
  elif e=='glute_bridge':ph='UP' if v and v>155 else 'DOWN' if v and v<130 else None
  else:ph='UP' if v and v>155 else 'DOWN' if v and v<115 else None
  return ph,v,'hip'
 if e=='jumping_jack':
  sc=dist(mid(p[LS],p[RS]),mid(p[LH],p[RH]));ft=dist(p[LF],p[RF]);v=None if not sc or ft is None else ft/sc;hi=ok(p,LW,RW,LS,RS)and p[LW][1]<p[LS][1]and p[RW][1]<p[RS][1];return('OPEN' if v and v>1.4 and hi else 'CLOSED' if v and v<.85 and not hi else None),v,'feet ratio'
 if e=='mountain_climber':
  sc=dist(mid(p[LS],p[RS]),mid(p[LH],p[RH]));l=dist(p[LK],p[LH]);r=dist(p[RK],p[RH]);v=None if not sc or l is None or r is None else min(l,r)/sc;return('LEFT' if sc and l and r and l/sc<.8 and r/sc>.85 else 'RIGHT' if sc and l and r and r/sc<.8 and l/sc>.85 else None),v,'knee ratio'
 if e=='plank':s,(a,b,c)=side(p,q,(LS,LH,LA),(RS,RH,RA));v=angle(p[a],p[b],p[c]);return('HOLD' if v and v>155 else None),v,'body'
 return None,None,'metric'

def update(e,c,s,t):
 dt=0 if s.last is None else min(t-s.last,.25);s.last=t
 if e=='plank':s.phase='HOLD' if c else 'REST';s.hold+=dt if c else 0;return
 if c is None or c==s.phase:s.cand=None;s.frames=0;return
 if c==s.cand:s.frames+=1
 else:s.cand=c;s.frames=1
 if s.frames<3:return
 s.phase=c;s.cand=None;s.frames=0;a,b=CYC[e]
 if c==a:s.start=True
 elif c==b and s.start:s.reps+=1;s.start=False

def pick_window():
 items=[]
 def cb(hwnd,_):
  if not win32gui.IsWindowVisible(hwnd):return
  title=win32gui.GetWindowText(hwnd).strip()
  if not title:return
  l,t,r,b=win32gui.GetWindowRect(hwnd)
  if r-l>=300 and b-t>=200:items.append((title,l,t,r-l,b-t))
 win32gui.EnumWindows(cb,None)
 for i,(title,_,_,w,h) in enumerate(items,1):print(f'{i:>3}. {title} [{w}x{h}]')
 while True:
  try:
   n=int(input('\nWindow number: '))
   if 1<=n<=len(items):return items[n-1]
  except ValueError:pass

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--exercise',default='push_up',choices=EXERCISES);ap.add_argument('--mode',choices=['side','front'],default='side');args=ap.parse_args()
 if not Path(MODEL).exists():urllib.request.urlretrieve(URL,MODEL)
 title,l,t,w,h=pick_window();mon={'left':l,'top':t,'width':w,'height':h}
 V=mp.tasks.vision;land=V.PoseLandmarker.create_from_options(V.PoseLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=MODEL),running_mode=V.RunningMode.VIDEO,num_poses=1,min_pose_detection_confidence=.4,min_pose_presence_confidence=.4,min_tracking_confidence=.5))
 grab=mss.MSS();state=State();last=time.perf_counter();cv2.namedWindow('Gym Pose',cv2.WINDOW_NORMAL);cv2.resizeWindow('Gym Pose',960,540)
 while True:
  img=np.asarray(grab.grab(mon))[:,:,:3].copy();ts=int(time.perf_counter()*1000);res=land.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(img,cv2.COLOR_BGR2RGB)),ts);metric='No reliable pose';feedback='POSE LOST - COUNTING PAUSED'
  if res.pose_landmarks:
   lm=res.pose_landmarks[0];wo=res.pose_world_landmarks[0];p=np.full((33,3),np.nan,np.float32);scr=np.full((33,2),np.nan,np.float32);q=np.zeros(33);now=time.perf_counter();ih,iw=img.shape[:2]
   for i,(x,z) in enumerate(zip(lm,wo)):
    q[i]=min(x.visibility,x.presence)
    if q[i]>=.4:p[i]=[state.filt[i][k].f(v,now)for k,v in enumerate((z.x,z.y,z.z))];scr[i]=[x.x*iw,x.y*ih]
   draw_connections=CON
   feedback=''
   metrics={}
   form_ok=True
   if args.exercise=='push_up':
    ph,feedback,form_ok,metrics=pushup_rules(p,q,scr,state,args.mode,now)
    if args.mode=='front':
     # Reuse the final result from pushup_rules(). Do not call the older
     # bilateral helper again because it would overwrite descent feedback
     # with the old hand-width check.
     elbow_metric=metrics.get('elbow')
     draw_connections=[(LS,RS),(LS,LE),(LE,LW),(RS,RE),(RE,RW)]
     point_ids=(LS,RS,LE,RE,LW,RW)
    else:
     arm_side,body_ids=side(p,q,(LS,LE,LW,LH,LK,LA),(RS,RE,RW,RH,RK,RA))
     sh,el,wr,hip,knee,ankle=body_ids
     draw_connections=[(sh,el),(el,wr),(sh,hip),(hip,knee),(knee,ankle)]
     point_ids=body_ids
    val=metrics.get('elbow');label='elbow';update(args.exercise,ph,state,now)
   else:
    point_ids=range(33);ph,val,label=profile(args.exercise,p,q,args.mode);update(args.exercise,ph,state,now)
   good=~np.isnan(p).any(1)
   for a,b in draw_connections:
    if good[a]and good[b]:
     color=(0,220,0) if form_ok else (0,0,255)
     cv2.line(img,tuple(scr[a].astype(int)),tuple(scr[b].astype(int)),color,2)
   for i in point_ids:
    v=scr[i]
    if good[i]:cv2.circle(img,tuple(v.astype(int)),4,(0,255,255),-1)
   metric=f'{label}: {val:.1f}' if val is not None else f'{label}: N/A'
   if args.exercise=='push_up':
    def fmt(k,n):
     v=metrics.get(k);return f'{n}: {v:.1f}' if v is not None else f'{n}: N/A'
    metric=' | '.join([fmt('elbow','Elbow'),fmt('body','Body'),fmt('knee','Knee'),fmt('flare','Flare'),fmt('hand_ratio','Hands')])
  now=time.perf_counter();fps=1/max(now-last,1e-6);last=now;count=f'Hold: {state.hold:.1f}s' if args.exercise=='plank' else f'Reps: {state.reps}'
  lines=[f'{args.exercise} | {args.mode.upper()}',count,f'Phase: {state.phase}',metric]+([feedback] if args.exercise=='push_up' and feedback else[])+[f'FPS: {fps:.1f}','Q quit | R reset']
  for i,x in enumerate(lines):cv2.putText(img,x,(15,30+i*28),cv2.FONT_HERSHEY_SIMPLEX,.58,(255,255,255),2)
  cv2.imshow('Gym Pose',img);k=cv2.waitKey(1)&255
  if k in(27,ord('q')):break
  if k==ord('r'):state.reset()
 land.close();grab.close();cv2.destroyAllWindows()
if __name__=='__main__':main()
