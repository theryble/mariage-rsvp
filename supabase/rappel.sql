-- Modèle du mail de rappel, partagé entre les administrateurs (page admin.html).
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run,
-- après supabase/admin.sql.
--
-- Seuls les comptes listés dans public.admins peuvent lire et modifier les réglages.

create table if not exists public.settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);
alter table public.settings enable row level security;
revoke all on public.settings from anon, authenticated;
grant select, insert, update, delete on public.settings to authenticated;

drop policy if exists "Admins gèrent les réglages" on public.settings;
create policy "Admins gèrent les réglages" on public.settings
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
