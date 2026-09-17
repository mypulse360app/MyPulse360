const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const patientId = '44444444-4444-4444-4444-444444444442'; // The logged in user
const newId = '55555555-5555-5555-5555-555555555555';

const sql = `
INSERT INTO public.chat_conversations (id, patient_id) 
VALUES ('${newId}', '${patientId}') 
RETURNING *;
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log('Insert Success:', res.rows);
    client.end();
  })
  .catch(err => {
    console.error('Insert Error:', err);
    client.end();
  });
