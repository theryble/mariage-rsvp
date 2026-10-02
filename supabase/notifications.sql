-- E-mail aux administrateurs à chaque réponse d'un invité (nouvelle ou modifiée).
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run,
-- APRÈS avoir enregistré la clé Resend dans le coffre (voir README.md, « Notifications »).
--
-- La base appelle l'API de Resend avec l'extension pg_net. La clé reste dans le coffre
-- chiffré de Supabase (Vault) : elle n'apparaît ni dans ce fichier ni dans les pages.
-- Un échec d'envoi n'empêche jamais l'enregistrement de la réponse.

create extension if not exists pg_net;

-- Adresse d'expédition. Sans nom de domaine vérifié chez Resend, seule l'adresse de
-- test onboarding@resend.dev fonctionne, et uniquement vers l'e-mail du compte Resend.
create or replace function public.notify_sender() returns text
language sql immutable
as $$ select 'Inscriptions vin d''honneur <onboarding@resend.dev>'::text $$;

create or replace function public.html_escape(s text) returns text
language sql immutable
as $$
  select replace(replace(replace(replace(coalesce(s, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;')
$$;

create or replace function public.notify_rsvp() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  api_key    text;
  recipients text[];
  is_new     boolean := (tg_op = 'INSERT');
  subject    text;
  body       text;
  presents   int;
  absents    int;
begin
  begin
    select decrypted_secret into api_key from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
    select array_agg(u.email) into recipients
      from public.admins a join auth.users u on u.id = a.user_id
      where u.email is not null;
    if api_key is null or recipients is null then
      return new;
    end if;

    select count(*) filter (where attending), count(*) filter (where not attending)
      into presents, absents from public.rsvps;

    subject := (case when is_new then 'Nouvelle réponse : ' else 'Réponse modifiée : ' end)
               || new.first_name || ' ' || new.last_name
               || (case when new.attending then ' sera présent(e)' else ' ne viendra pas' end);

    body :=
      '<div style="font-family:Georgia,serif;color:#3a2e28;max-width:520px">'
      || '<p style="font-size:13px;letter-spacing:2px;text-transform:uppercase;color:#a98249;margin:0 0 6px">Vin d''honneur · 22.08.2027</p>'
      || '<h1 style="font-size:24px;font-weight:600;margin:0 0 16px">'
      ||   (case when is_new then 'Nouvelle réponse' else 'Réponse modifiée' end) || '</h1>'
      || '<table style="font-family:Arial,sans-serif;font-size:15px;border-collapse:collapse">'
      || '<tr><td style="padding:4px 16px 4px 0;color:#6b5c53">Invité</td><td style="padding:4px 0"><b>'
      ||   public.html_escape(new.first_name || ' ' || new.last_name) || '</b></td></tr>'
      || '<tr><td style="padding:4px 16px 4px 0;color:#6b5c53">Réponse</td><td style="padding:4px 0;color:'
      ||   (case when new.attending then '#5d8a6a"><b>Présent(e)' else '#a0585a"><b>Absent(e)' end) || '</b></td></tr>'
      || (case when new.contact <> '' then '<tr><td style="padding:4px 16px 4px 0;color:#6b5c53">Contact</td><td style="padding:4px 0">'
           || public.html_escape(new.contact) || '</td></tr>' else '' end)
      || (case when new.message <> '' then '<tr><td style="padding:4px 16px 4px 0;color:#6b5c53;vertical-align:top">Message</td><td style="padding:4px 0">'
           || replace(public.html_escape(new.message), E'\n', '<br>') || '</td></tr>' else '' end)
      || '<tr><td style="padding:4px 16px 4px 0;color:#6b5c53">Reçue le</td><td style="padding:4px 0">'
      ||   to_char(now() at time zone 'Europe/Paris', 'DD/MM/YYYY à HH24:MI') || '</td></tr>'
      || '</table>'
      || '<p style="font-family:Arial,sans-serif;font-size:14px;margin:20px 0 0;color:#6b5c53">À ce jour : <b style="color:#5d8a6a">'
      ||   presents || ' présent(s)</b> · <b style="color:#a0585a">' || absents || ' absent(s)</b></p>'
      || '<p style="font-family:Arial,sans-serif;font-size:14px;margin:16px 0 0">'
      || '<a href="https://theryble.github.io/mariage-rsvp/admin.html" style="color:#a85f76">Ouvrir l''espace mariés</a></p>'
      || '</div>';

    perform net.http_post(
      url     := 'https://api.resend.com/emails',
      headers := jsonb_build_object('Authorization', 'Bearer ' || api_key, 'Content-Type', 'application/json'),
      body    := jsonb_build_object('from', public.notify_sender(), 'to', to_jsonb(recipients),
                                    'subject', subject, 'html', body)
    );
  exception when others then
    raise warning 'notify_rsvp : envoi impossible (%)', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function public.notify_rsvp() from public, anon, authenticated;

drop trigger if exists rsvps_notify on public.rsvps;
create trigger rsvps_notify
  after insert or update on public.rsvps
  for each row execute function public.notify_rsvp();
