const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
CREATE POLICY chat_conversations_insert_patient 
ON public.chat_conversations 
FOR INSERT TO authenticated 
WITH CHECK (patient_id::text = auth.uid()::text);
`;

client.connect()
  .then(() => client.query(sql))
  .then(() => {
    console.log('Successfully created INSERT policy on chat_conversations.');
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
