-- Drop the old table if you ran it previously to start fresh
drop table if exists public.support_tickets;

create table public.support_tickets (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  
  -- User Information
  user_email text not null,
  user_name text,
  user_id uuid, 
  
  -- Ticket Details
  subject text not null,
  message text not null,
  platform text default 'ios'::text, 
  app_version text,                  
  screenshot text, -- Stores the image as a Base64 text string
  
  -- Internal Management
  status text default 'open'::text not null, 
  notes text                                
);

alter table public.support_tickets enable row level security;

create policy "Allow public anonymous inserts" 
on public.support_tickets for insert with check (true);

create policy "Allow authenticated admins to select/update" 
on public.support_tickets for all to authenticated using (true);
