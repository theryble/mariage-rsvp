-- Accès privé aux réponses pour la page admin.html.
-- À exécuter une seule fois dans Supabase : SQL Editor → New query → coller → Run,
-- APRÈS avoir créé ton compte dans Authentication → Users → Add user.
--
-- Seuls les comptes listés dans public.admins peuvent lire et supprimer les réponses.
-- Les invités (clé publique) n'y ont toujours aucun accès.

create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

-- Vérifie si la personne connectée est administratrice (lecture de admins sans y donner accès).
create or replace function public.is_admin() returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

grant select, delete on public.rsvps to authenticated;

drop policy if exists "Admins lisent les réponses" on public.rsvps;
create policy "Admins lisent les réponses" on public.rsvps
  for select to authenticated using (public.is_admin());

drop policy if exists "Admins suppriment les réponses" on public.rsvps;
create policy "Admins suppriment les réponses" on public.rsvps
  for delete to authenticated using (public.is_admin());

-- ⬇️ Remplacer l'adresse par celle du compte créé dans Authentication → Users.
insert into public.admins (user_id)
select id from auth.users where email = 'ton.adresse@exemple.fr'
on conflict do nothing;

-- Vérification : doit afficher ton adresse.
select u.email from public.admins a join auth.users u on u.id = a.user_id;
