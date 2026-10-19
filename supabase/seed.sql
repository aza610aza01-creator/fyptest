-- =============================================================================
-- AI GYM CLOUD - SEED DATA FOR EXERCISES, BADGES, AND CHALLENGES
-- =============================================================================

insert into public.exercises (
  name,
  muscle_group,
  secondary_muscles,
  equipment,
  instructions,
  cues,
  common_mistakes,
  demo_url,
  illustration_url,
  is_active
)
values
  (
    'Squat',
    'Legs',
    array['Glutes', 'Core', 'Lower Back'],
    'Barbell',
    'Stand with feet shoulder-width apart, brace your core, hinge hips back and bend knees to lower until thighs are parallel to the floor, then drive through mid-foot to stand.',
    array['Chest proud and neutral spine', 'Knees track over toes', 'Brace 360 degrees around core'],
    array['Knees caving inward (valgus)', 'Rounding lower back at the bottom', 'Lifting heels off the floor'],
    'https://example.com/demos/squat',
    'assets/illustrations/squat.png',
    true
  ),
  (
    'Push-up',
    'Chest',
    array['Triceps', 'Anterior Deltoids', 'Core'],
    'Bodyweight',
    'Start in a high plank with hands slightly wider than shoulders. Lower your chest cleanly toward the floor while keeping elbows at a 45-degree angle, then press back up.',
    array['Maintain a rigid plank line', 'Tuck elbows at 45 degrees', 'Full lockout at the top'],
    array['Sagging hips or lumbar hyperextension', 'Flaring elbows to 90 degrees', 'Half repetitions'],
    'https://example.com/demos/pushup',
    'assets/illustrations/pushup.png',
    true
  ),
  (
    'Deadlift',
    'Back',
    array['Hamstrings', 'Glutes', 'Forearms', 'Core'],
    'Barbell',
    'Stand with mid-foot under the barbell, grip just outside legs, pull slack out of the bar, brace lats and core, and drive the floor away until hips and knees lock out.',
    array['Keep the bar close to shins', 'Engage lats (protect armpits)', 'Hinge at the hips on descent'],
    array['Rounding lumbar spine', 'Jerking the bar off the floor', 'Hyperextending the back at lockout'],
    'https://example.com/demos/deadlift',
    'assets/illustrations/deadlift.png',
    true
  ),
  (
    'Bench Press',
    'Chest',
    array['Triceps', 'Anterior Deltoids'],
    'Barbell',
    'Lie on the flat bench with eyes under the bar, retract shoulder blades, plant feet firmly, lower the bar with control to lower chest, and press upward slightly back toward the rack.',
    array['Retract and depress scapula', 'Drive feet into floor for stability', 'Wrists stacked straight over elbows'],
    array['Bouncing bar off the chest', 'Lifting hips off the bench', 'Bent wrists under load'],
    'https://example.com/demos/bench-press',
    'assets/illustrations/bench_press.png',
    true
  ),
  (
    'Shoulder Press',
    'Shoulders',
    array['Triceps', 'Upper Chest', 'Core'],
    'Dumbbell',
    'Sit or stand tall with dumbbells at shoulder height, brace abs and glutes, press weights overhead until arms are aligned with ears, and lower with control.',
    array['Squeeze glutes and ribs down', 'Press vertically in a controlled arc', 'Keep head neutral'],
    array['Excessive lower back arch', 'Using leg drive when performing strict press', 'Shortening range of motion'],
    'https://example.com/demos/shoulder-press',
    'assets/illustrations/shoulder_press.png',
    true
  ),
  (
    'Bicep Curl',
    'Arms',
    array['Forearms', 'Brachialis'],
    'Dumbbell',
    'Stand tall holding dumbbells with palms facing forward, keep elbows pinned by your sides, curl weights toward shoulders, squeeze biceps, and lower slowly.',
    array['Elbows stay stationary at ribs', 'Supinate wrists fully at top', 'Control the 2-second eccentric'],
    array['Swinging torso for momentum', 'Moving elbows forward', 'Dropping the weight rapidly'],
    'https://example.com/demos/bicep-curl',
    'assets/illustrations/bicep_curl.png',
    true
  ),
  (
    'Plank',
    'Core',
    array['Shoulders', 'Glutes'],
    'Bodyweight',
    'Support your body on forearms and toes with elbows directly under shoulders. Maintain a straight line from head to heels while breathing steadily.',
    array['Push forearms actively into floor', 'Posteriorly tilt pelvis slightly', 'Breathe behind the shield'],
    array['Hips dropping toward floor', 'Looking up and straining neck', 'Holding breath'],
    'https://example.com/demos/plank',
    'assets/illustrations/plank.png',
    true
  ),
  (
    'Running',
    'Cardio',
    array['Quadriceps', 'Calves', 'Hamstrings', 'Cardiovascular'],
    'Treadmill / Outdoor',
    'Maintain an upright posture with a slight forward lean from the ankles, land softly under your center of mass, and keep a steady cadence and rhythmic breathing.',
    array['Relax shoulders and hands', 'Quick light cadence', 'Land under hips, not ahead'],
    array['Overstriding with heavy heel strike', 'Tensing upper body', 'Starting intervals without warm-up'],
    'https://example.com/demos/running',
    'assets/illustrations/running.png',
    true
  ),
  (
    'Cycling',
    'Cardio',
    array['Quadriceps', 'Glutes', 'Calves', 'Cardiovascular'],
    'Stationary Bike / Road',
    'Set saddle height so knee retains a slight bend at the bottom of the pedal stroke. Pedal smoothly through full circles while keeping upper body relaxed.',
    array['Smooth 360-degree pedal stroke', 'Neutral spine and light grip', 'Maintain target RPM cadence'],
    array['Saddle too low causing knee strain', 'Rocking hips side to side', 'Locking elbows rigidly'],
    'https://example.com/demos/cycling',
    'assets/illustrations/cycling.png',
    true
  )
on conflict (name) do update
set muscle_group = excluded.muscle_group,
    secondary_muscles = excluded.secondary_muscles,
    equipment = excluded.equipment,
    instructions = excluded.instructions,
    cues = excluded.cues,
    common_mistakes = excluded.common_mistakes,
    is_active = true;

-- Seed default badges
insert into public.badges (code, title_en, title_zh, description_en, description_zh, icon_name, threshold_value)
values
  ('first_workout', 'First Session', '首次訓練', 'Complete your first logged workout.', '完成您的第一次訓練記錄。', 'fitness_center', 1),
  ('streak_3', '3-Day Streak', '連續3天訓練', 'Train on 3 consecutive days.', '連續3天完成訓練。', 'local_fire_department', 3),
  ('streak_7', '7-Day Streak', '連續7天訓練', 'Maintain a 7-day training streak.', '保持連續7天訓練紀錄。', 'bolt', 7),
  ('volume_10k', '10,000 kg Club', '萬公斤俱樂部', 'Accumulate 10,000 kg of total training volume.', '累積達到 10,000 公斤總訓練容量。', 'workspace_premium', 10000),
  ('vision_scanner', 'AI Vision Pioneer', 'AI 視覺先鋒', 'Log your first ML Kit camera object detection.', '完成首次 ML Kit 相機物件偵測記錄。', 'center_focus_strong', 1)
on conflict (code) do nothing;

-- Seed default community challenges
insert into public.challenges (title, description, metric_type, target_value, start_date, end_date, is_active)
values
  ('30-Day Consistency Challenge', 'Complete 12 structured workouts inside 30 days.', 'workouts_count', 12, current_date, current_date + 30, true),
  ('50 km Cardio Endurance', 'Log 50 km across Running or Cycling sessions.', 'distance_km', 50, current_date, current_date + 30, true);
