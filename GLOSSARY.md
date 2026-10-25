# AI Gym Cloud — Domain Glossary

| Canonical Term | Domain Definition |
| :--- | :--- |
| **Athlete** | A person using AI Gym Cloud to log workouts, track body & health metrics, or evaluate exercise posture via the camera coach, either in **Guest Mode** or as a **Verified Cloud Athlete**. |
| **Verified Cloud Athlete** | An Athlete who has completed both Step-1 Email/Password authentication and Step-2 6-digit Email OTP verification. |
| **Guest Mode** | A local-only session allowing an Athlete to use workout logging, body tracking, and real-time camera posture coaching before creating a cloud account. |
| **Guest Migration** | The idempotent transfer of local Guest Mode workouts, routines, measurements, health logs, goals, and saved detections into a newly verified cloud account without data loss or duplication. |
| **Workout Draft** | An autosaved, in-progress training session containing logged sets, notes, start timestamp, and active rest-timer target UTC timestamp that survives app restarts or interruptions. |
| **Posture Evaluation** | A real-time biomechanical assessment of a target exercise (Squat, Bicep Curl, Shoulder Press, or Deadlift) producing a form score (0–100%), primary/secondary joint angles, left/right symmetry percentage, and a three-tier status (`Correct`, `Needs Adjustment`, or `Incorrect`). |
| **Real-Time Detection Showcase** | The live telemetry stream displaying the current **Posture Evaluation**, 17-keypoint skeleton alignment, detected gym equipment, and sportswear items on both the Camera Coach and Home screens. |
| **Design Token** | A named, versioned visual value (color, typography, 8pt spacing, radius, or motion seed) with audited Light Mode and Dark Mode values and measured WCAG 2.2 contrast ratios. |
