-- Migration 0010: Pharmacist Dispense Permissions & Queue Completion
-- Grants the pharmacist role permission to insert prescriptions, complete appointments, and update consultations.

-- 1. Prescriptions: Allow pharmacists to insert prescriptions when verifying & dispensing
create policy prescriptions_pharmacist_insert on public.prescriptions
  for insert to authenticated
  with check (public.auth_role() in ('doctor', 'pharmacist'));

-- 2. Prescriptions: Ensure pharmacists can update prescriptions
create policy prescriptions_pharmacist_update_all on public.prescriptions
  for update to authenticated
  using (public.auth_role() in ('doctor', 'pharmacist'))
  with check (public.auth_role() in ('doctor', 'pharmacist'));

-- 3. Prescription Items: Allow staff insert
create policy prescription_items_staff_insert on public.prescription_items
  for insert to authenticated
  with check (public.auth_role() in ('doctor', 'pharmacist'));

-- 4. Appointments: Allow pharmacists to update appointment status to 'completed'
create policy appointments_pharmacist_update on public.appointments
  for update to authenticated
  using (public.auth_role() in ('doctor', 'pharmacist'))
  with check (public.auth_role() in ('doctor', 'pharmacist'));

-- 5. Consultations: Allow pharmacists to update consultation status
create policy consultations_pharmacist_update on public.consultations
  for update to authenticated
  using (public.auth_role() in ('doctor', 'pharmacist'))
  with check (public.auth_role() in ('doctor', 'pharmacist'));
