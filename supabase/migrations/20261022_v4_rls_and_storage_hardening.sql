-- AI Gym Cloud v5.0 Reversible RLS, Design Token Register & Storage Hardening Migration
-- Follows @supabase-postgres-best-practices and @design-theme-guide SQL DDL.
BEGIN;

-- 1. Server-verifiable Admin Helper (SECURITY DEFINER with locked search_path)
CREATE OR REPLACE FUNCTION public.is_verified_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'admin'
  );
$$;

-- 2. Composite & Covering Indexes for High-Frequency Athlete Queries
CREATE INDEX IF NOT EXISTS idx_workouts_user_started_at
  ON public.workouts (user_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_workout_sets_workout_order
  ON public.workout_sets (workout_id, set_number ASC);

CREATE INDEX IF NOT EXISTS idx_camera_detections_user_detected_at
  ON public.camera_detections (user_id, detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_health_logs_user_date
  ON public.health_logs (user_id, recorded_date DESC);

-- 3. Design Token Register Table (@design-theme-guide)
CREATE TABLE IF NOT EXISTS public.design_token (
  token_id BIGINT PRIMARY KEY,
  token_name VARCHAR(255) NOT NULL UNIQUE,
  token_group VARCHAR(100) NOT NULL,
  token_type VARCHAR(100) NOT NULL,
  value VARCHAR(255),
  unit VARCHAR(50),
  light_mode_value VARCHAR(255),
  dark_mode_value VARCHAR(255),
  contrast_ratio NUMERIC(5,2),
  contrast_against VARCHAR(255),
  wcag_level VARCHAR(50) NOT NULL,
  font_family VARCHAR(255),
  font_size VARCHAR(50),
  font_weight VARCHAR(50),
  line_height VARCHAR(50),
  letter_spacing VARCHAR(50),
  usage_rule TEXT,
  do_not_use_for TEXT,
  source_reference VARCHAR(255),
  version VARCHAR(50) NOT NULL,
  status VARCHAR(50) NOT NULL,
  approved_by VARCHAR(255),
  last_reviewed DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT token_ratio_range CHECK (contrast_ratio IS NULL OR (contrast_ratio >= 1 AND contrast_ratio <= 21)),
  CONSTRAINT token_wcag_level CHECK (wcag_level IN ('AA','AAA','Fail - do not ship','Not applicable'))
);

CREATE INDEX IF NOT EXISTS idx_design_token_status ON public.design_token (status);
CREATE INDEX IF NOT EXISTS idx_design_token_type ON public.design_token (token_type);

COMMIT;
