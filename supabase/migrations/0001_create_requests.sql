-- ============================================================================
-- CrabKing's Lair — 3D artwork requests
-- Run in: Supabase dashboard → SQL Editor (the CrabKing's Lair project)
-- ============================================================================

create table if not exists public.requests (
  id            uuid primary key default gen_random_uuid(),
  card_name     text not null,
  name          text not null,
  email         text,
  mobile        text,
  artwork_type  text not null check (artwork_type in ('Full', 'Half', 'Not sure')),
  notes         text,
  created_at    timestamptz not null default now(),

  -- Copy says "name, email or mobile" — require at least one way to reply.
  constraint requests_contact_required
    check (nullif(btrim(coalesce(email, '')), '') is not null
        or nullif(btrim(coalesce(mobile, '')), '') is not null)
);

alter table public.requests enable row level security;

-- The website submits with the anon (publishable) key: insert only.
-- No select policy, so submitted requests are readable only via the
-- service role / dashboard.
drop policy if exists "Anyone can submit a request" on public.requests;
create policy "Anyone can submit a request"
  on public.requests
  for insert
  to anon, authenticated
  with check (true);

create index if not exists requests_created_at_idx
  on public.requests (created_at desc);
