-- Migration 0010: Create Staff Account RPC
-- Enables doctors to provision staff accounts directly with appropriate role, auth credentials, and profiles.

create or replace function public.create_staff_account(
  p_email text,
  p_temp_password text,
  p_full_name text,
  p_role public.user_role
)
returns public.profiles
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_caller_role public.user_role;
  v_clinic uuid;
  v_user_id uuid;
  v_profile public.profiles;
begin
  select role, clinic_id into v_caller_role, v_clinic
  from public.profiles where id = auth.uid();

  if v_caller_role is null or v_caller_role != 'doctor' then
    raise exception 'Only doctors can create staff accounts.' using errcode = '42501';
  end if;

  if p_role not in ('doctor', 'pharmacist') then
    raise exception 'Staff accounts must be doctor or pharmacist.' using errcode = '22023';
  end if;

  if exists (select 1 from public.profiles where email = p_email) or
     exists (select 1 from auth.users where email = p_email) then
    raise exception 'That email is already in use.' using errcode = '23505';
  end if;

  v_user_id := gen_random_uuid();

  insert into auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    role,
    aud,
    confirmation_token,
    recovery_token,
    email_change,
    email_change_token_new
  ) values (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    p_email,
    extensions.crypt(p_temp_password, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  );

  insert into public.profiles (
    id, email, full_name, role, clinic_id, must_change_password
  ) values (
    v_user_id, p_email, p_full_name, p_role, v_clinic, true
  ) returning * into v_profile;

  if p_role = 'doctor' then
    insert into public.doctor_profiles (id, license_number, specialization, clinic_id, average_rating)
    values (v_user_id, 'MD-' || substr(v_user_id::text, 1, 8), 'General practice', v_clinic, 5.0)
    on conflict do nothing;
  elsif p_role = 'pharmacist' then
    insert into public.pharmacist_profiles (id, license_number, clinic_id)
    values (v_user_id, 'RP-' || substr(v_user_id::text, 1, 8), v_clinic)
    on conflict do nothing;
  end if;

  return v_profile;
end;
$$;

revoke all on function public.create_staff_account(text, text, text, public.user_role) from public, anon;
grant execute on function public.create_staff_account(text, text, text, public.user_role) to authenticated;
