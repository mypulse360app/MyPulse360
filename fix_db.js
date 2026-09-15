const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
-- Registration writes profiles, patient_profiles and the doctor assignment.
create or replace function public.register_patient(
  p_full_name text, p_email text
)
returns public.profiles
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_clinic uuid;
  v_row    public.profiles;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'that account already has a profile' using errcode = '23505';
  end if;

  select id into v_clinic from public.clinics order by name limit 1;
  if v_clinic is null then
    raise exception 'no clinic is configured' using errcode = 'P0002';
  end if;

  insert into public.profiles (id, email, full_name, role, clinic_id)
  values (auth.uid(), p_email, p_full_name, 'patient', v_clinic)
  returning * into v_row;

  insert into public.patient_profiles (id, height_cm, weight_kg)
  values (auth.uid(), 0, 0);

  begin
    perform public.assign_default_doctor(auth.uid());
  exception when sqlstate 'P0002' then
    null;
  end;

  return v_row;
end;
$$;

revoke all on function public.register_patient(text, text) from public, anon;
grant execute on function public.register_patient(text, text) to authenticated;
`;

client.connect()
  .then(() => client.query(sql))
  .then(() => {
    console.log('Successfully created register_patient function.');
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
