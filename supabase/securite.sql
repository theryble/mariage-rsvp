-- Durcissement suggéré par Supabase → Advisors → Security Advisor (à exécuter une fois).
-- Ne change rien pour les invités ni pour l'espace mariés.

-- 1. Chemin de recherche figé (alerte « Function Search Path Mutable »).
alter function public.ping() set search_path = '';
alter function public.notify_sender() set search_path = '';
alter function public.html_escape(text) set search_path = '';

-- 2. Fonctions internes : seule la notification e-mail (notify_rsvp) s'en sert.
revoke execute on function public.notify_sender() from public, anon, authenticated;
revoke execute on function public.html_escape(text) from public, anon, authenticated;
revoke execute on function public.response_deadline() from public, anon, authenticated;

-- 3. is_admin ne sert qu'aux mariés connectés.
revoke execute on function public.is_admin() from anon;

-- 4. Le formulaire appelle submit_rsvp et report_absence sans compte (rôle anon) :
--    un compte connecté n'en a pas besoin.
revoke execute on function public.submit_rsvp(uuid, text, text, text, text, text, text) from authenticated;
revoke execute on function public.report_absence(uuid, text) from authenticated;

-- Restent volontairement publiques (alertes normales, le formulaire en a besoin) :
--   submit_rsvp, report_absence, get_deadline (anon) ; get_deadline, is_admin (mariés connectés).
