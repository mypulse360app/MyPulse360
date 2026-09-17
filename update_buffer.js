const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
CREATE OR REPLACE FUNCTION public.available_slots(p_doctor uuid, p_date date)
 RETURNS TABLE(slot_at timestamp with time zone, is_booked boolean, is_doctor_on_leave boolean, is_past boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with tz as (
    select public.clinic_tz(p_doctor) as zone
  ),
  avail as (
    select start_time, end_time, slot_minutes
    from public.doctor_availability
    where doctor_id = p_doctor
      and day_of_week = extract(isodow from p_date)::smallint
      and is_active
  ),
  on_leave as (
    select exists (
      select 1 from public.leave_requests l
      where l.doctor_id = p_doctor and l.status = 'approved'
        and p_date between l.start_date and l.end_date
    ) as flag
  ),
  slots as (
    select generate_series(
             (p_date + a.start_time) at time zone (select zone from tz),
             (p_date + a.end_time)   at time zone (select zone from tz)
               - make_interval(mins => a.slot_minutes),
             make_interval(mins => a.slot_minutes)
           ) as slot_at
    from avail a
  )
  select s.slot_at,
         exists (
           select 1 from public.appointments ap
           where ap.doctor_id = p_doctor
             and ap.scheduled_at = s.slot_at
             and ap.status <> 'cancelled'
         ) as is_booked,
         (select flag from on_leave) as is_doctor_on_leave,
         s.slot_at < (now() + interval '1 hour') as is_past
  from slots s
  order by s.slot_at
$function$;
`;

client.connect()
  .then(() => client.query(sql))
  .then(() => {
    console.log('Successfully updated available_slots with 1 hour buffer.');
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
