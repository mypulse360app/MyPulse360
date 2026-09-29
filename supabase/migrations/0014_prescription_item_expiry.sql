-- Migration 0014: Prescription patient-scan & items support
--
-- 1. Add per-item expiry_date to prescription_items
-- 2. Ensure prescriptions.source accepts 'in_app', 'scanned_external', 'manual_external'
-- 3. RLS policies with UUID-compatible auth.uid() matching

-- 1. Medication-level expiry date (nullable — doctor items may not have one)
alter table public.prescription_items
  add column if not exists expiry_date timestamptz null;

-- 2. Update prescriptions.source check constraint if needed
do $$
begin
  alter table public.prescriptions drop constraint if exists prescriptions_source_check;
  alter table public.prescriptions add constraint prescriptions_source_check
    check (source in ('in_app', 'scanned_external', 'manual_external'));
exception when others then
  null;
end $$;

-- 3. RLS — Drop old conflicting policies safely
drop policy if exists prescriptions_patient_insert on public.prescriptions;
drop policy if exists prescription_items_patient_insert on public.prescription_items;
drop policy if exists prescription_items_read_parties on public.prescription_items;
drop policy if exists prescription_items_patient_select on public.prescription_items;
drop policy if exists prescriptions_patient_delete on public.prescriptions;
drop policy if exists prescription_items_patient_delete on public.prescription_items;

-- 4. Recreate RLS policies using native UUID matching
-- Allow patients to insert their own prescriptions
create policy prescriptions_patient_insert
  on public.prescriptions for insert to authenticated
  with check (patient_id = auth.uid());

-- Allow patients to insert prescription_items linked to their prescriptions
create policy prescription_items_patient_insert
  on public.prescription_items for insert to authenticated
  with check (
    exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id
        and p.patient_id = auth.uid()
    )
  );

-- Allow patients, doctors, and pharmacists to select prescription_items
create policy prescription_items_patient_select
  on public.prescription_items for select to authenticated
  using (
    exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id
        and (
          p.patient_id = auth.uid()
          or (p.doctor_id = auth.uid() and p.source = 'in_app')
          or p.pharmacist_id = auth.uid()
          or public.auth_role() = 'pharmacist'
        )
    )
  );

-- 5. Allow patients to delete their own prescriptions
create policy prescriptions_patient_delete
  on public.prescriptions for delete to authenticated
  using (patient_id = auth.uid());

create policy prescription_items_patient_delete
  on public.prescription_items for delete to authenticated
  using (
    exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id
        and p.patient_id = auth.uid()
    )
  );
