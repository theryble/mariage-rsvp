-- Date limite des réponses réglable depuis l'espace mariés (admin.html).
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run,
-- après date-limite.sql et empechement.sql.
--
-- La date est rangée dans public.settings (clé « deadline », ex. {"date": "2027-05-31"}) :
-- c'est le dernier jour où les invités peuvent modifier leur réponse (jusqu'à 23h59, heure
-- de Paris). Sans réglage, la date par défaut reste le 31 mai 2027.

-- Table des réglages (déjà créée par rappel.sql, recréée ici au besoin).
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
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Dernier jour de réponse. Lisible par tous (la page l'affiche), modifiable par les admins seulement.
create or replace function public.get_deadline() returns date
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select (value ->> 'date')::date from public.settings
      where key = 'deadline' and value ->> 'date' ~ '^\d{4}-\d{2}-\d{2}$'),
    date '2027-05-31');
$$;
revoke all on function public.get_deadline() from public;
grant execute on function public.get_deadline() to anon, authenticated;

-- Instant de fermeture : le lendemain du dernier jour, à minuit heure de Paris.
create or replace function public.response_deadline() returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select ((public.get_deadline() + 1)::timestamp at time zone 'Europe/Paris');
$$;
revoke all on function public.response_deadline() from public;

create or replace function public.submit_rsvp(
  p_id uuid,
  p_first_name text,
  p_last_name text,
  p_attending text,
  p_contact text default '',
  p_message text default '',
  p_website text default ''
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Champ piège rempli : c'est un robot, on ignore sans erreur.
  if coalesce(p_website, '') <> '' then
    return;
  end if;
  if p_attending not in ('yes', 'no') then
    raise exception 'présence invalide';
  end if;
  -- Après la date limite réglée, une réponse déjà envoyée ne peut plus être modifiée.
  if now() >= public.response_deadline()
     and exists (select 1 from public.rsvps where id = p_id) then
    raise exception 'modifications_closes';
  end if;

  insert into public.rsvps (id, first_name, last_name, attending, contact, message)
  values (
    p_id,
    left(btrim(p_first_name), 60),
    left(btrim(p_last_name), 60),
    p_attending = 'yes',
    left(btrim(coalesce(p_contact, '')), 120),
    left(btrim(coalesce(p_message, '')), 600)
  )
  on conflict (id) do update set
    first_name = excluded.first_name,
    last_name  = excluded.last_name,
    attending  = excluded.attending,
    contact    = excluded.contact,
    message    = excluded.message,
    updated_at = now();
end;
$$;

revoke all on function public.submit_rsvp(uuid, text, text, text, text, text, text) from public;
grant execute on function public.submit_rsvp(uuid, text, text, text, text, text, text) to anon;
