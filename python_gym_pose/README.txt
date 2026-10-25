Windows YOLO camera feed for the Flutter app

1. Run SETUP.bat once. It creates .venv and installs the camera, MediaPipe, and Ultralytics dependencies.
2. Run RUN_FLUTTER.bat and allow Python to use the webcam. The first YOLO run may download yolov8n-pose.pt.
3. Open the Flutter app's Camera screen. It connects to http://127.0.0.1:8765 and displays the annotated camera feed and YOLO detections.
4. Keep the Python window open while using the Flutter feed. Close it with Ctrl+C when finished.

The bridge binds to localhost only. Use --camera-index N with gym_pose_yolo.py if the default webcam is not the camera you want. The existing RUN_SIDE.bat and RUN_FRONT.bat scripts continue to launch the standalone pose coach.
