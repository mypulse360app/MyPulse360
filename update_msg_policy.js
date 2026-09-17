const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:sarvinmohaiminjotha123@db.arxrtodtnrmhwbecwyxm.supabase.co:5432/postgres',
  ssl: { rejectUnauthorized: false }
});

const sql = `
DROP POLICY IF EXISTS chat_messages_sender_insert ON public.chat_messages;

CREATE POLICY chat_messages_sender_insert ON public.chat_messages 
FOR INSERT TO authenticated 
WITH CHECK (
  sender_id::text = auth.uid()::text 
  OR sender_id::text = '22222222-2222-2222-2222-222222222221'
);
`;

client.connect()
  .then(() => client.query(sql))
  .then((res) => {
    console.log('Updated AI reply insert policy');
    client.end();
  })
  .catch(err => {
    console.error('Error executing query', err);
    client.end();
  });
