#!/usr/bin/env python3
"""
AI Gym Cloud v6.6 — Hybrid Ultralytics YOLO + MediaPipe PoseLandmarker Real-Time Lens & Screen Engine
Supports both --source screen (mss + win32gui window capture) and --source lens (OpenCV VideoCapture webcam/lens),
plus all 14 exercises and v10 Front/Side biomechanical rules from gym_pose.py.
"""
import argparse, base64, json, math, threading, time, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import cv2, numpy as np, mediapipe as mp
from gym_pose import (
    MODEL, URL, EXERCISES, CON, CYC, LS, RS, LE, RE, LW, RW, LH, RH, LK, RK, LA, RA, LF, RF,
    State, pushup_rules, profile, update, side, pick_window
)

try:
    from ultralytics import YOLO
    HAS_YOLO = True
except Exception:
    HAS_YOLO = False


class BridgeState:
    def __init__(self):
        self.lock = threading.Lock()
        self.active = True
        self.snapshot = None

    def publish(self, snapshot):
        with self.lock:
            self.snapshot = snapshot

    def read_snapshot(self):
        with self.lock:
            return self.snapshot


def start_bridge(state, host, port):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/health':
                body = json.dumps({'ready': True, 'active': state.active}).encode()
                self.send_response(200)
            elif self.path == '/snapshot':
                snapshot = state.read_snapshot()
                if snapshot is None:
                    body = b'{"ready":false,"error":"Waiting for the first camera frame"}'
                    self.send_response(503)
                else:
                    body = json.dumps(snapshot).encode()
                    self.send_response(200)
            else:
                body = b'{"error":"Not found"}'
                self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            if self.path != '/control':
                self.send_error(404)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                payload = json.loads(self.rfile.read(length).decode('utf-8'))
                if not isinstance(payload.get('active'), bool):
                    raise ValueError('active must be a boolean')
                state.active = payload['active']
                body = json.dumps({'active': state.active}).encode()
                self.send_response(200)
            except (ValueError, json.JSONDecodeError) as error:
                body = json.dumps({'error': str(error)}).encode()
                self.send_response(400)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, _format, *_args):
            return

    server = ThreadingHTTPServer((host, port), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def run_hybrid():
    ap = argparse.ArgumentParser(description="AI Gym Cloud v6.6 YOLO + PoseLandmarker Real-Time Engine")
    ap.add_argument('--exercise', default='push_up', choices=EXERCISES)
    ap.add_argument('--mode', choices=['side', 'front'], default='side')
    ap.add_argument('--source', choices=['screen', 'lens'], default='lens', help='Capture live camera lens or screen window')
    ap.add_argument('--camera-index', type=int, default=0)
    ap.add_argument('--yolo-weights', default='yolov8n-pose.pt')
    ap.add_argument('--serve', action='store_true', help='Stream annotated frames and detections to the Flutter Windows app')
    ap.add_argument('--bridge-host', default='127.0.0.1')
    ap.add_argument('--bridge-port', type=int, default=8765)
    args = ap.parse_args()

    if args.serve and args.source != 'lens':
        ap.error('--serve currently requires --source lens')

    if not Path(MODEL).exists():
        urllib.request.urlretrieve(URL, MODEL)

    yolo_model = None
    if args.serve and not HAS_YOLO:
        raise RuntimeError('YOLO is unavailable. Run SETUP.bat to install ultralytics.')
    if HAS_YOLO:
        try:
            yolo_model = YOLO(args.yolo_weights)
        except Exception as error:
            if args.serve:
                raise RuntimeError(f'Could not load YOLO weights "{args.yolo_weights}": {error}') from error
            print(f'YOLO disabled: could not load weights "{args.yolo_weights}": {error}')
    elif not args.serve:
        print('YOLO disabled: install ultralytics and provide YOLO weights to enable detection.')

    V = mp.tasks.vision
    land = V.PoseLandmarker.create_from_options(
        V.PoseLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=MODEL),
            running_mode=V.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.4,
            min_pose_presence_confidence=0.4,
            min_tracking_confidence=0.5,
        )
    )

    cap = None
    grab = None
    mon = None
    if args.source == 'screen':
        import mss
        title, l, t, w, h = pick_window()
        mon = {'left': l, 'top': t, 'width': w, 'height': h}
        grab = mss.MSS()
    else:
        cap = cv2.VideoCapture(args.camera_index)
        if not cap.isOpened():
            raise RuntimeError(f'Could not open camera index {args.camera_index}.')

    state = State()
    bridge_state = BridgeState() if args.serve else None
    bridge_server = start_bridge(bridge_state, args.bridge_host, args.bridge_port) if args.serve else None
    last = time.perf_counter()
    frame_number = 0
    if not args.serve:
        cv2.namedWindow('AI Gym Cloud v6.6 — YOLO + Gym Pose', cv2.WINDOW_NORMAL)
        cv2.resizeWindow('AI Gym Cloud v6.6 — YOLO + Gym Pose', 960, 540)

    while True:
        if bridge_state is not None and not bridge_state.active:
            if cap is not None:
                cap.release()
                cap = None
            time.sleep(0.1)
            continue
        if bridge_state is not None and cap is None:
            cap = cv2.VideoCapture(args.camera_index)
            if not cap.isOpened():
                cap.release()
                cap = None
                time.sleep(0.5)
                continue

        if grab is not None:
            img = np.asarray(grab.grab(mon))[:, :, :3].copy()
        else:
            ok_frame, img = cap.read()
            if not ok_frame:
                break

        yolo_detections = []
        inference_ms = 0.0
        if yolo_model is not None:
            yolo_started = time.perf_counter()
            y_res = yolo_model.predict(img, conf=0.45, iou=0.50, verbose=False)
            inference_ms = (time.perf_counter() - yolo_started) * 1000.0
            for r in y_res:
                for b in r.boxes:
                    x1, y1, x2, y2 = map(int, b.xyxy[0].tolist())
                    cls_id = int(b.cls[0].item())
                    conf = float(b.conf[0].item())
                    yolo_detections.append({
                        'class_id': cls_id,
                        'label': r.names.get(cls_id, 'object'),
                        'confidence': conf,
                        'box': {'left': x1, 'top': y1, 'right': x2, 'bottom': y2},
                    })
                    cv2.rectangle(img, (x1, y1), (x2, y2), (212, 245, 0), 2)
                    cv2.putText(img, f"YOLO {r.names.get(cls_id, 'obj')} {conf:.2f}", (x1, max(18, y1 - 6)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (212, 245, 0), 2)

        ts = int(time.perf_counter() * 1000)
        res = land.detect_for_video(
            mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(img, cv2.COLOR_BGR2RGB)),
            ts,
        )
        metric = 'No reliable pose'
        feedback = 'POSE LOST - COUNTING PAUSED'
        if res.pose_landmarks:
            lm = res.pose_landmarks[0]
            wo = res.pose_world_landmarks[0]
            p = np.full((33, 3), np.nan, np.float32)
            scr = np.full((33, 2), np.nan, np.float32)
            q = np.zeros(33)
            now = time.perf_counter()
            ih, iw = img.shape[:2]
            for i, (x, z) in enumerate(zip(lm, wo)):
                q[i] = min(x.visibility, x.presence)
                if q[i] >= 0.4:
                    p[i] = [state.filt[i][k].f(v, now) for k, v in enumerate((z.x, z.y, z.z))]
                    scr[i] = [x.x * iw, x.y * ih]
            draw_connections = CON
            feedback = ''
            metrics = {}
            form_ok = True
            if args.exercise == 'push_up':
                ph, feedback, form_ok, metrics = pushup_rules(p, q, scr, state, args.mode, now)
                if args.mode == 'front':
                    draw_connections = [(LS, RS), (LS, LE), (LE, LW), (RS, RE), (RE, RW)]
                    point_ids = (LS, RS, LE, RE, LW, RW)
                else:
                    arm_side, body_ids = side(p, q, (LS, LE, LW, LH, LK, LA), (RS, RE, RW, RH, RK, RA))
                    sh, el, wr, hip, knee, ankle = body_ids
                    draw_connections = [(sh, el), (el, wr), (sh, hip), (hip, knee), (knee, ankle)]
                    point_ids = body_ids
                val = metrics.get('elbow')
                label = 'elbow'
                update(args.exercise, ph, state, now)
            else:
                point_ids = range(33)
                ph, val, label = profile(args.exercise, p, q, args.mode)
                update(args.exercise, ph, state, now)

            good = ~np.isnan(p).any(1)
            for a, b in draw_connections:
                if good[a] and good[b]:
                    color = (0, 220, 0) if form_ok else (0, 0, 255)
                    cv2.line(img, tuple(scr[a].astype(int)), tuple(scr[b].astype(int)), color, 2)
            for i in point_ids:
                v = scr[i]
                if good[i]:
                    cv2.circle(img, tuple(v.astype(int)), 4, (0, 255, 255), -1)
            metric = f'{label}: {val:.1f}' if val is not None else f'{label}: N/A'
            if args.exercise == 'push_up':
                def fmt(k, n):
                    v = metrics.get(k)
                    return f'{n}: {v:.1f}' if v is not None else f'{n}: N/A'
                metric = ' | '.join([fmt('elbow', 'Elbow'), fmt('body', 'Body'), fmt('knee', 'Knee'), fmt('flare', 'Flare'), fmt('hand_ratio', 'Hands')])

        now = time.perf_counter()
        fps = 1 / max(now - last, 1e-6)
        last = now
        count = f'Hold: {state.hold:.1f}s' if args.exercise == 'plank' else f'Reps: {state.reps}'
        lines = [f'{args.exercise} | {args.mode.upper()} | {args.source.upper()}', count, f'Phase: {state.phase}', metric] + ([feedback] if args.exercise == 'push_up' and feedback else []) + [f'FPS: {fps:.1f}', 'Q quit | R reset']
        for i, x in enumerate(lines):
            cv2.putText(img, x, (15, 30 + i * 28), cv2.FONT_HERSHEY_SIMPLEX, 0.58, (255, 255, 255), 2)
        frame_number += 1
        if bridge_state is not None:
            encoded_ok, encoded_frame = cv2.imencode(
                '.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 75]
            )
            if encoded_ok:
                height, width = img.shape[:2]
                bridge_state.publish({
                    'ready': True,
                    'frame': base64.b64encode(encoded_frame).decode('ascii'),
                    'frame_number': frame_number,
                    'width': width,
                    'height': height,
                    'inference_ms': inference_ms,
                    'fps': fps,
                    'exercise': args.exercise,
                    'phase': state.phase,
                    'reps': state.reps,
                    'detections': yolo_detections,
                })

        if not args.serve:
            cv2.imshow('AI Gym Cloud v6.6 — YOLO + Gym Pose', img)
            k = cv2.waitKey(1) & 255
            if k in (27, ord('q')):
                break
            if k == ord('r'):
                state.reset()

    land.close()
    if bridge_server is not None:
        bridge_server.shutdown()
        bridge_server.server_close()
    if grab is not None:
        grab.close()
    if cap is not None:
        cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    run_hybrid()
