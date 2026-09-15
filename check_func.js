const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
SELECT EXISTS (
    SELECT 1 
    FROM pg_proc 
    WHERE proname = 'assign_default_doctor'
) as "exists";
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log('assign_default_doctor exists:', res.rows[0].exists);
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
