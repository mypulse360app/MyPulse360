const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

client.connect()
  .then(() => client.query('SELECT count(*) FROM public.clinics'))
  .then((res) => {
    console.log('Clinics count:', res.rows[0].count);
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
