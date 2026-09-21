-- Migration 0013: Automatic Display ID Generation for Profiles (P1, D1, CA1)
-- Generates human-friendly sequential IDs while preserving UUID primary keys.

-- 1. Ensure display_id column exists with unique constraint
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_id text UNIQUE;

-- 2. Create sequences for each role
CREATE SEQUENCE IF NOT EXISTS public.patient_display_id_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS public.doctor_display_id_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS public.ca_display_id_seq START WITH 1;

-- 3. Trigger function to auto-assign display_id on INSERT if not provided
CREATE OR REPLACE FUNCTION public.assign_profile_display_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Only assign if display_id is null or empty
  IF NEW.display_id IS NULL OR TRIM(NEW.display_id) = '' THEN
    IF NEW.role::text = 'patient' THEN
      NEW.display_id := 'P' || nextval('public.patient_display_id_seq');
    ELSIF NEW.role::text = 'doctor' THEN
      NEW.display_id := 'D' || nextval('public.doctor_display_id_seq');
    ELSIF NEW.role::text IN ('pharmacist', 'clinic_assistant') THEN
      NEW.display_id := 'CA' || nextval('public.ca_display_id_seq');
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Attach trigger to public.profiles
DROP TRIGGER IF EXISTS trigger_assign_profile_display_id ON public.profiles;
CREATE TRIGGER trigger_assign_profile_display_id
  BEFORE INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_profile_display_id();

-- 5. Backfill existing records that do not have a display_id
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT id, role 
    FROM public.profiles 
    WHERE display_id IS NULL 
    ORDER BY created_at ASC 
  LOOP
    IF r.role::text = 'patient' THEN
      UPDATE public.profiles 
      SET display_id = 'P' || nextval('public.patient_display_id_seq') 
      WHERE id = r.id;
    ELSIF r.role::text = 'doctor' THEN
      UPDATE public.profiles 
      SET display_id = 'D' || nextval('public.doctor_display_id_seq') 
      WHERE id = r.id;
    ELSIF r.role::text IN ('pharmacist', 'clinic_assistant') THEN
      UPDATE public.profiles 
      SET display_id = 'CA' || nextval('public.ca_display_id_seq') 
      WHERE id = r.id;
    END IF;
  END LOOP;
END $$;

-- 6. Synchronize sequences to the highest existing numbers to prevent collision
SELECT setval(
  'public.patient_display_id_seq',
  COALESCE((SELECT MAX(SUBSTRING(display_id FROM 2)::bigint) FROM public.profiles WHERE display_id ~ '^P[0-9]+$'), 0) + 1,
  false
);

SELECT setval(
  'public.doctor_display_id_seq',
  COALESCE((SELECT MAX(SUBSTRING(display_id FROM 2)::bigint) FROM public.profiles WHERE display_id ~ '^D[0-9]+$'), 0) + 1,
  false
);

SELECT setval(
  'public.ca_display_id_seq',
  COALESCE((SELECT MAX(SUBSTRING(display_id FROM 3)::bigint) FROM public.profiles WHERE display_id ~ '^CA[0-9]+$'), 0) + 1,
  false
);
