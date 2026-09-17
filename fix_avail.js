const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
BEGIN;

-- Delete existing availability
DELETE FROM public.doctor_availability;

-- Re-insert with lunch break for Dr. Ahmed (2222...1) and Dr. Lina (2222...2)
INSERT INTO public.doctor_availability (doctor_id, day_of_week, start_time, end_time, slot_minutes)
SELECT docs.doctor_id, days.day_of_week, '09:00:00'::time, '12:00:00'::time, 30
FROM (SELECT unnest(ARRAY['22222222-2222-2222-2222-222222222221', '22222222-2222-2222-2222-222222222222']::uuid[]) as doctor_id) docs
CROSS JOIN (SELECT unnest(ARRAY[1,2,3,4,5]) as day_of_week) days;

INSERT INTO public.doctor_availability (doctor_id, day_of_week, start_time, end_time, slot_minutes)
SELECT docs.doctor_id, days.day_of_week, '13:00:00'::time, '17:00:00'::time, 30
FROM (SELECT unnest(ARRAY['22222222-2222-2222-2222-222222222221', '22222222-2222-2222-2222-222222222222']::uuid[]) as doctor_id) docs
CROSS JOIN (SELECT unnest(ARRAY[1,2,3,4,5]) as day_of_week) days;

COMMIT;
`;

client.connect()
  .then(() => client.query(sql))
  .then(() => {
    console.log('Successfully updated doctor_availability with lunch break.');
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
