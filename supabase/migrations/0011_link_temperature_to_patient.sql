-- Migration 0011: Link Temperature to Patient
-- Adds patient_id and appointment_id to temperature_logs

-- 1. Add columns to temperature_logs
alter table public.temperature_logs 
  add column patient_id text references public.profiles(id),
  add column appointment_id text references public.appointments(id);

-- 2. Update RLS Policies for temperature_logs
-- Drop existing policies if any (from migration 0009)
drop policy if exists temperature_logs_read on public.temperature_logs;
drop policy if exists temperature_logs_insert on public.temperature_logs;

-- Re-enable RLS (should already be enabled but good practice)
alter table public.temperature_logs enable row level security;

-- Policy: Patients can read their own logs, Staff can read all logs
create policy temperature_logs_read on public.temperature_logs
  for select to authenticated 
  using (
    patient_id = auth.uid()::text 
    or 
    public.auth_role() in ('doctor', 'pharmacist', 'clinical_assistant') -- Assuming clinical staff roles
    or
    patient_id is null -- Allow reading unassigned logs from IoT devices
  );

-- Policy: IoT devices or staff can insert logs
create policy temperature_logs_insert on public.temperature_logs
  for insert to authenticated 
  with check (true); -- Usually you'd restrict this to specific roles or service roles

-- Policy: Staff can update logs (e.g. to assign patient_id to an unassigned log from IoT)
create policy temperature_logs_update on public.temperature_logs
  for update to authenticated
  using (public.auth_role() in ('doctor', 'pharmacist', 'clinical_assistant'))
  with check (public.auth_role() in ('doctor', 'pharmacist', 'clinical_assistant'));

