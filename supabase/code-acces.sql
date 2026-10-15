-- Code d'accès par formulaire (Réglages → Formulaires → « Protéger ce formulaire par un code »).
-- À exécuter une fois dans Supabase : SQL Editor → New query → coller → Run, après invites.sql.
--
-- Un formulaire protégé ne montre ses textes et n'accepte une réponse qu'avec le bon code. Les codes en
-- clair sont rangés sous la clé « form_codes » ({"mariage": "AB12CD"}), que seuls les mariés peuvent lire ;
-- la page publique ne les reçoit jamais. Les majuscules et les espaces ne comptent pas.

-- Le code donné ouvre-t-il ce formulaire ? (toujours vrai pour un formulaire sans protection)
create or replace function public.form_code_ok(p_event text, p_code text) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not coalesce((select (value -> 'list' -> p_event -> 'access' ->> 'on')::boolean
                         from public.settings where key = 'forms'), false) then true
    else coalesce((
      select coalesce(value ->> p_event, '') <> ''
         and upper(regexp_replace(value ->> p_event, '\s', '', 'g')) = upper(regexp_replace(coalesce(p_code, ''), '\s', '', 'g'))
        from public.settings where key = 'form_codes'), false)
  end;
$$;
revoke all on function public.form_code_ok(text, text) from public, anon, authenticated;

-- Formulaire d'une fête pour la page publique (comme dans invites.sql), avec le code :
-- sans le bon code, seuls le nom de la fête et « locked » sont renvoyés.
drop function if exists public.get_form_config(text);
create or replace function public.get_form_config(p_event text default null, p_code text default null) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with f as (select value as v from public.settings where key = 'forms'),
       s as (select x.key as id from f, jsonb_each(f.v -> 'list') as x(key, value)
              where nullif(p_event, '') is not null and (x.key = p_event or x.value ->> 'slug' = p_event)
              order by (x.key = p_event) desc limit 1),
       e as (select coalesce((select id from s), nullif(p_event, ''), (select v ->> 'main' from f), 'vin') as id),
       fm as (select v -> 'list' -> (select id from e) as form from f)
  select case
    when (select form from fm) is not null and not public.form_code_ok((select id from e), p_code)
      then jsonb_build_object('configured', true, 'event', (select id from e), 'locked', true,
                              'name', (select form ->> 'name' from fm))
    else jsonb_build_object(
      'configured', exists (select 1 from f),
      'event', (select id from e),
      'form', (select form - 'access' from fm),
      'logo', (select value from public.settings where key = 'logo:' || (select id from e)))
  end;
$$;
revoke all on function public.get_form_config(text, text) from public;
grant execute on function public.get_form_config(text, text) to anon, authenticated;

-- Enregistrement d'une réponse (comme dans invites.sql), refusé sans le bon code pour un formulaire protégé.
drop function if exists public.submit_rsvp(uuid, text, text, text, text, text, text, text);
create or replace function public.submit_rsvp(
  p_id uuid,
  p_first_name text,
  p_last_name text,
  p_attending text,
  p_contact text default '',
  p_message text default '',
  p_website text default '',
  p_event text default 'vin',
  p_code text default null
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
  -- Formulaire protégé : il faut le bon code.
  if not public.form_code_ok(p_event, p_code) then
    raise exception 'code_invalide';
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
revoke all on function public.submit_rsvp(uuid, text, text, text, text, text, text, text, text) from public;
grant execute on function public.submit_rsvp(uuid, text, text, text, text, text, text, text, text) to anon;
