const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
SELECT * FROM public.doctor_availability LIMIT 10;
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log(res.rows);
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
