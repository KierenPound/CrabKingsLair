-- ============================================================================
-- CrabKing's Lair — reset requests table with notes column
-- Safe for local/test data reset: drops and recreates public.requests
-- Run in: Supabase dashboard → SQL Editor
-- ============================================================================

drop policy if exists "Anyone can submit a request" on public.requests;
drop table if exists public.requests;

create table public.requests (
  id            uuid primary key default gen_random_uuid(),
  card_name     text not null,
  name          text not null,
  email         text,
  mobile        text,
  artwork_type  text not null check (artwork_type in ('Full', 'Half', 'Not sure')),
  notes         text,
  created_at    timestamptz not null default now(),

  constraint requests_contact_required
    check (nullif(btrim(coalesce(email, '')), '') is not null
        or nullif(btrim(coalesce(mobile, '')), '') is not null)
);

alter table public.requests enable row level security;

create policy "Anyone can submit a request"
  on public.requests
  for insert
  to anon, authenticated
  with check (true);

create index if not exists requests_created_at_idx
  on public.requests (created_at desc);
