const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
SELECT distinct day_of_week FROM public.doctor_availability;
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log('Days of week with availability:', res.rows.map(r => r.day_of_week));
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
