-- Date limite du 31 mai 2027 : met à jour la fonction submit_rsvp.
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run.
-- Après le 31 mai 2027 à 23h59 (heure de Paris), une réponse déjà envoyée ne peut plus être modifiée.

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
