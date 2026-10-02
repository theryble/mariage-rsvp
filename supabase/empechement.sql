-- Signalement d'un empêchement après la date limite (31 mai 2027).
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run,
-- après supabase/date-limite.sql.
--
-- Après la date limite, un invité qui avait répondu « Présent(e) » ne peut plus modifier sa
-- réponse, mais peut signaler un empêchement : sa réponse passe en absent, avec la date et
-- un mot facultatif. Avant la date limite, il suffit de modifier sa réponse.

alter table public.rsvps add column if not exists cancelled_at timestamptz;
alter table public.rsvps add column if not exists cancel_message text not null default ''
  check (char_length(cancel_message) <= 600);

create or replace function public.report_absence(p_id uuid, p_message text default '')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.rsvps
     set attending      = false,
         cancelled_at   = now(),
         cancel_message = left(btrim(coalesce(p_message, '')), 600),
         updated_at     = now()
   where id = p_id
     and attending
     and cancelled_at is null;
  if not found then
    raise exception 'empechement_impossible';
  end if;
end;
$$;

revoke all on function public.report_absence(uuid, text) from public;
grant execute on function public.report_absence(uuid, text) to anon;
