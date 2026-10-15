-- Listes d'invités par jour de fête, tenues à la main par les mariés (onglet « Invités » d'admin.html).
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run,
-- après admin.sql et date-limite-reglable.sql (ce script remplace submit_rsvp pour y ajouter la fête).
--
-- Les jours de fête (nom + date) sont rangés dans public.settings (clé « events ») et se règlent
-- dans l'onglet Réglages. Chaque invité porte, dans « events », les jours où il est invité et sa
-- présence pour chacun : {"mariage": "yes", "vin": "pending"} (yes, no ou pending).
-- Les invités (clé publique) n'y ont aucun accès.

create table if not exists public.guests (
  id          uuid primary key default gen_random_uuid(),
  first_name  text not null default '' check (char_length(first_name) <= 60),
  last_name   text not null default '' check (char_length(last_name) <= 60),
  contact     text not null default '' check (char_length(contact) <= 120),
  age         text not null default 'adult' check (age in ('adult', 'child', 'baby')),
  role        text not null default 'guest' check (role in ('guest', 'family', 'friend', 'work', 'plus', 'photo', 'video')),
  plus_of     uuid references public.guests (id) on delete set null,
  witness     boolean not null default false,
  rsvp        jsonb not null default '{}'::jsonb check (jsonb_typeof(rsvp) = 'object'),
  events     jsonb not null default '{}'::jsonb check (jsonb_typeof(events) = 'object'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- Contact facultatif (e-mail ou téléphone) et âge (adult par défaut, child ou baby ; les
-- bébés n'ont pas de repas) : ajoutés aussi si la table existait déjà.
alter table public.guests add column if not exists contact text not null default ''
  check (char_length(contact) <= 120);
alter table public.guests add column if not exists age text not null default 'adult'
  check (age in ('adult', 'child', 'baby'));
-- Catégorie : invité par défaut, famille, amis, travail, accompagnant, ou photographe / vidéaste (prestataires,
-- comptés pour le repas).
alter table public.guests add column if not exists role text not null default 'guest'
  check (role in ('guest', 'family', 'friend', 'work', 'plus', 'photo', 'video'));
-- Un accompagnant est rattaché à l'invité qu'il accompagne (plus_of) ; son prénom est facultatif,
-- celui des autres reste obligatoire.
alter table public.guests add column if not exists plus_of uuid references public.guests (id) on delete set null;
-- Témoin des mariés (en plus de sa catégorie).
alter table public.guests add column if not exists witness boolean not null default false;
-- Réponses au formulaire rattachées à l'invité, une par jour de fête : {"vin": "<id de la réponse>"}.
alter table public.guests add column if not exists rsvp jsonb not null default '{}'::jsonb
  check (jsonb_typeof(rsvp) = 'object');
alter table public.guests alter column first_name set default '';
alter table public.guests drop constraint if exists guests_first_name_check;
alter table public.guests add constraint guests_first_name_check check (char_length(first_name) <= 60);
alter table public.guests drop constraint if exists guests_name_required;
alter table public.guests add constraint guests_name_required check (role = 'plus' or char_length(first_name) >= 1);
alter table public.guests enable row level security;
revoke all on public.guests from anon, authenticated;
grant select, insert, update, delete on public.guests to authenticated;
drop policy if exists "Admins gèrent les invités" on public.guests;
create policy "Admins gèrent les invités" on public.guests
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

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

-- Jours de fête de départ, modifiables ensuite dans Réglages.
insert into public.settings (key, value) values ('events', '{"list": [
  {"id": "vin",     "name": "Vin d''honneur",   "date": "2027-08-22", "start": "17:15", "end": "19:00"},
  {"id": "mariage", "name": "Mariage",          "date": "2027-08-14"},
  {"id": "fete22",  "name": "Fête du 22 août",  "date": "2027-08-22"}
]}'::jsonb)
on conflict (key) do nothing;

-- ---------- Un formulaire par jour de fête ----------
-- Les formulaires (Réglages → Formulaires) sont rangés sous la clé « forms » :
-- {"main": "vin", "list": {"vin": {"open": true, "name": …, "date": …, "place": …, "intro": …}, …}}.
-- « main » est le formulaire ouvert par l'adresse simple ; les autres s'ouvrent avec ?fete=<id>.

-- Chaque réponse indique sa fête (le vin d'honneur pour les réponses déjà reçues).
alter table public.rsvps add column if not exists event text not null default 'vin'
  check (event ~ '^[A-Za-z0-9_-]{1,40}$');

-- Formulaire d'une fête pour la page publique : la fête demandée, sinon le formulaire principal.
-- configured = faux tant qu'aucun formulaire n'a été réglé (la page garde alors le vin d'honneur d'origine).
drop function if exists public.get_form_config();
create or replace function public.get_form_config(p_event text default null) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with f as (select value as v from public.settings where key = 'forms'),
       -- ?fete= accepte l'adresse lisible d'un formulaire (« slug », ex. fete-du-22-aout) ou son identifiant.
       s as (select x.key as id from f, jsonb_each(f.v -> 'list') as x(key, value)
              where nullif(p_event, '') is not null and (x.key = p_event or x.value ->> 'slug' = p_event)
              order by (x.key = p_event) desc limit 1),
       e as (select coalesce((select id from s), nullif(p_event, ''), (select v ->> 'main' from f), 'vin') as id)
  select jsonb_build_object(
    'configured', exists (select 1 from f),
    'event', (select id from e),
    'form', (select v -> 'list' -> (select id from e) from f),
    -- Logo personnalisé de la fête (clé « logo:<fête> » : {"light": image, "dark": image}), s'il existe.
    'logo', (select value from public.settings where key = 'logo:' || (select id from e))
  );
$$;
revoke all on function public.get_form_config(text) from public;
grant execute on function public.get_form_config(text) to anon, authenticated;

-- Fin des modifications pour un formulaire : sa propre date limite (Réglages → Formulaires), sinon la
-- date limite par défaut ; le lendemain à minuit, heure de Paris.
create or replace function public.form_deadline(p_event text) returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select ((coalesce(
    (select (value -> 'list' -> p_event ->> 'deadline')::date from public.settings
      where key = 'forms' and value -> 'list' -> p_event ->> 'deadline' ~ '^\d{4}-\d{2}-\d{2}$'),
    public.get_deadline()) + 1)::timestamp at time zone 'Europe/Paris');
$$;
revoke all on function public.form_deadline(text) from public, anon, authenticated;

-- Enregistrement d'une réponse, avec sa fête (mêmes règles que date-limite-reglable.sql,
-- avec la date limite propre au formulaire).
drop function if exists public.submit_rsvp(uuid, text, text, text, text, text, text);
create or replace function public.submit_rsvp(
  p_id uuid,
  p_first_name text,
  p_last_name text,
  p_attending text,
  p_contact text default '',
  p_message text default '',
  p_website text default '',
  p_event text default 'vin'
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
  if coalesce(p_event, '') !~ '^[A-Za-z0-9_-]{1,40}$' then
    raise exception 'fête invalide';
  end if;
  -- Après la date limite de ce formulaire, une réponse déjà envoyée ne peut plus être modifiée.
  if now() >= public.form_deadline(p_event)
     and exists (select 1 from public.rsvps where id = p_id) then
    raise exception 'modifications_closes';
  end if;

  insert into public.rsvps (id, first_name, last_name, attending, contact, message, event)
  values (
    p_id,
    left(btrim(p_first_name), 60),
    left(btrim(p_last_name), 60),
    p_attending = 'yes',
    left(btrim(coalesce(p_contact, '')), 120),
    left(btrim(coalesce(p_message, '')), 600),
    p_event
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
revoke all on function public.submit_rsvp(uuid, text, text, text, text, text, text, text) from public;
grant execute on function public.submit_rsvp(uuid, text, text, text, text, text, text, text) to anon;
