const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
SELECT public.clinic_tz('22222222-2222-2222-2222-222222222221') as tz;
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log('Clinic TZ:', res.rows[0].tz);
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
