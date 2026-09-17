const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
SELECT pg_get_functiondef(p.oid) AS func_def
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.proname = 'available_slots';
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    if (res.rows.length > 0) {
      console.log(res.rows[0].func_def);
    } else {
      console.log('Function not found.');
    }
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
