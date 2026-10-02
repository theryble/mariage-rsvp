-- Base des réponses au vin d'honneur de Marine & Jeremy.
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run.
--
-- Sécurité : la page publique n'a le droit que d'appeler submit_rsvp (enregistrer ou
-- mettre à jour SA réponse, identifiée par un UUID aléatoire connu de son seul appareil).
-- Elle ne peut ni lire, ni lister, ni supprimer les réponses.

create table if not exists public.rsvps (
  id          uuid primary key,
  first_name  text not null check (char_length(first_name) between 1 and 60),
  last_name   text not null check (char_length(last_name) between 1 and 60),
  attending   boolean not null,
  contact     text not null default '' check (char_length(contact) <= 120),
  message     text not null default '' check (char_length(message) <= 600),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- RLS activée sans aucune règle : personne ne lit ni n'écrit directement la table
-- depuis l'API publique. Seule la fonction ci-dessous y écrit.
alter table public.rsvps enable row level security;
revoke all on public.rsvps from anon, authenticated;

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
  -- Date limite : après le 31 mai 2027 (heure de Paris), une réponse déjà envoyée ne peut plus être modifiée.
  if now() >= timestamptz '2027-06-01 00:00 Europe/Paris'
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

-- Appelée tous les 3 jours par .github/workflows/keepalive.yml pour que Supabase
-- ne mette pas le projet gratuit en pause faute d'activité.
create or replace function public.ping() returns text
language sql
stable
as $$ select 'ok'::text $$;

revoke all on function public.ping() from public;
grant execute on function public.ping() to anon;

-- Vue lisible pour consulter les réponses (Table Editor → « reponses »), en heure de Paris.
-- security_invoker : la vue respecte les droits de la table, donc reste invisible au public.
create or replace view public.reponses with (security_invoker = true) as
select
  first_name                                                       as "Prénom",
  last_name                                                        as "Nom",
  case when attending then 'Présent(e)' else 'Absent(e)' end       as "Présence",
  contact                                                          as "Contact",
  message                                                          as "Message",
  to_char(created_at at time zone 'Europe/Paris', 'DD/MM/YYYY HH24:MI') as "Reçue le",
  to_char(updated_at at time zone 'Europe/Paris', 'DD/MM/YYYY HH24:MI') as "Modifiée le"
from public.rsvps
order by last_name, first_name;

revoke all on public.reponses from anon, authenticated;
