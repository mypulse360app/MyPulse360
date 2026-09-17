const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
INSERT INTO public.profiles (id, email, full_name, role, is_active, clinic_id) 
VALUES ('00000000-0000-0000-0000-000000000000', 'ai@mypulse360.test', 'AI Assistant', 'doctor', true, '11111111-1111-1111-1111-111111111111')
ON CONFLICT (id) DO NOTHING;
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log('Inserted AI profile');
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
