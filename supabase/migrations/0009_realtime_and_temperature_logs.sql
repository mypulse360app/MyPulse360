-- Migration 0009: Temperature Logs & Supabase Realtime Publication
-- Creates temperature_logs table for hardware IoT scanner and enables realtime streaming.

-- 1. Temperature Logs Table
create table if not exists public.temperature_logs (
  id bigint generated always as identity primary key,
  temperature numeric not null,
  status text not null default 'normal',
  device text not null default 'Lobby Scanner',
  created_at timestamptz not null default now()
);

-- RLS
alter table public.temperature_logs enable row level security;

create policy temperature_logs_read on public.temperature_logs
  for select to authenticated using (true);

create policy temperature_logs_insert on public.temperature_logs
  for insert with check (true);

-- 2. Add Tables to Supabase Realtime Publication
-- Enables live websocket event streaming for appointments, consultations, prescriptions, and temperature logs
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.appointments;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.consultations;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.prescriptions;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.prescription_items;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.temperature_logs;
    exception when duplicate_object then null;
    end;
  end if;
end $$;
