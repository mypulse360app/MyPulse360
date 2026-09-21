-- Migration 0012: Pharmacist Consultation Insert Policy
-- Allows pharmacists (clinic assistants) to INSERT consultation records
-- when logging vitals for a patient. Previously only doctors could insert
-- consultations (via consultations_doctor_write policy), but the clinic
-- assistant's logTemperature() workflow needs to create an in_progress
-- consultation when one doesn't already exist for the appointment.

CREATE POLICY consultations_pharmacist_insert ON public.consultations
  FOR INSERT TO authenticated
  WITH CHECK (public.auth_role() = 'pharmacist');

-- 2. Performance Indexes on temperature_logs
-- Speed up queries by appointment_id (e.g. AppointmentDetailPage)
CREATE INDEX IF NOT EXISTS idx_temp_logs_appointment_id 
  ON public.temperature_logs (appointment_id);

-- Speed up queries by patient_id (e.g. Patient Profile / History)
CREATE INDEX IF NOT EXISTS idx_temp_logs_patient_id 
  ON public.temperature_logs (patient_id);

-- Partial index for high-speed retrieval of unassigned scans from IoT scanners
CREATE INDEX IF NOT EXISTS idx_temp_logs_unassigned 
  ON public.temperature_logs (created_at DESC) 
  WHERE patient_id IS NULL;

-- 3. Replica Identity for Supabase Realtime
-- Ensures all columns are included in Realtime UPDATE change payloads
ALTER TABLE public.temperature_logs REPLICA IDENTITY FULL;

