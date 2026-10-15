# Inscription au vin d'honneur — Marine & Jeremy

Page d'inscription au vin d'honneur du 22 août 2027 (17h15 – 19h, Manoir des Lys, Auchel).
La page est hébergée sur GitHub Pages : <https://theryble.github.io/mariage-rsvp/>.
Les réponses sont enregistrées dans une base Supabase. Les invités n'ont besoin d'aucun compte.

```
index.html                         la page du formulaire
admin.html                         le tableau des réponses, réservé aux mariés
assets/                            logos (clair et sombre)
supabase/schema.sql                création de la base (à exécuter une fois)
supabase/admin.sql                 accès des mariés au tableau (à exécuter une fois)
supabase/notifications.sql         e-mail aux mariés à chaque réponse (à exécuter une fois)
supabase/rappel.sql                modèle du mail de rappel, partagé entre mariés (à exécuter une fois)
supabase/date-limite.sql           blocage des modifications après le 31 mai 2027 (à exécuter une fois)
supabase/empechement.sql           signalement d'un empêchement après le 31 mai (à exécuter une fois)
supabase/date-limite-reglable.sql  date limite réglable depuis l'espace mariés (à exécuter une fois)
supabase/securite.sql              durcissement conseillé par le Security Advisor (à exécuter une fois)
supabase/invites.sql               listes d'invités par jour de fête (à exécuter une fois)
supabase/code-acces.sql            code d'accès par formulaire (à exécuter une fois, après invites.sql)
.github/workflows/keepalive.yml    garde la base gratuite éveillée
```

## Étape 1 — Créer le projet Supabase

1. Créer un compte sur <https://supabase.com> (connexion possible avec GitHub).
2. **New project** :
   - **Name** : `mariage-rsvp`
   - **Database password** : cliquer sur *Generate a password* (il ne servira pas ici, inutile de le noter)
   - **Region** : *West EU (Paris)* ou la plus proche
3. **Create new project**, puis attendre une à deux minutes.

## Étape 2 — Créer la base

1. Menu de gauche : **SQL Editor** → **New query**.
2. Coller tout le contenu de `supabase/schema.sql`.
3. Cliquer sur **Run**. Le message attendu est « Success. No rows returned ».

## Étape 3 — Relier la page

1. Menu de gauche : **Project Settings** (roue dentée) → **Data API** : copier la **Project URL**
   (`https://xxxxxxxx.supabase.co`).
2. **Project Settings → API Keys** : copier la **Publishable key** (`sb_publishable_…`).
   Si seule l'ancienne présentation existe, prendre la clé **anon public** (elle commence par `eyJ`).
   Ne jamais utiliser la clé **secret** ou **service_role**.
3. Dans `index.html`, remplir :

   ```js
   const SUPABASE_URL = 'https://xxxxxxxx.supabase.co';
   const SUPABASE_KEY = 'sb_publishable_…';
   ```

La clé publique peut figurer dans la page : la base ne lui permet qu'une seule chose, enregistrer une réponse.
Elle ne peut ni lire ni supprimer les réponses des autres.

## Lire les réponses

### Avec le tableau privé

1. Supabase → **Authentication → Users → Add user → Create new user** : ton e-mail, un mot de passe,
   cocher **Auto Confirm User**.
2. Supabase → **Authentication → Sign In / Providers** : désactiver **Allow new users to sign up**,
   pour que personne d'autre ne puisse créer de compte.
3. Dans `supabase/admin.sql`, remplacer `ton.adresse@exemple.fr` par ton e-mail, puis l'exécuter dans
   **SQL Editor**. La dernière ligne doit afficher ton adresse.
4. Ouvrir <https://theryble.github.io/mariage-rsvp/admin.html> et se connecter.

Le tableau affiche les présents, les absents et le total, permet de chercher un nom, de filtrer, de
supprimer une réponse (deux clics pour confirmer) et d'exporter en CSV pour Excel. La session reste
ouverte sur l'appareil jusqu'à « Se déconnecter ».

Le bouton **Partager**, en haut à côté de « Se déconnecter » (visible une fois connecté), affiche
un QR code qui ouvre le formulaire (à scanner avec l'appareil photo d'un téléphone ou à télécharger en PNG
pour l'imprimer) et un bouton « Copier l'URL » pour envoyer le lien.

### Listes d'invités par jour de fête

L'onglet **Invités** de l'espace mariés range les invités par jour de fête (au départ : vin d'honneur,
mariage du 14 août 2027, fête du 22 août 2027). Les jours sont classés par date, puis par heure de
début, et sont repliés par défaut (le chevron les déplie).

Chaque invité est une cellule : verte s'il est présent, rouge s'il est absent, neutre tant qu'on ne
sait pas. Un clic sur le nom fait passer de « en attente » à « présent » puis « absent » ; le crayon
permet de changer ses informations ou de le supprimer. Un même invité peut être présent un jour et
absent un autre.

En ajoutant un invité, on indique :
- les jours où il est convié ;
- un e-mail ou un téléphone (facultatif) ;
- son âge : adulte (par défaut), enfant ou bébé ;
- sa catégorie : Invité (par défaut), Famille, Amis, Travail, Accompagnant, Photographe ou Vidéaste.
  Un accompagnant se rattache à un invité existant et s'affiche « Accompagnant 1 de Camille Dupont » ;
  son prénom est facultatif ;
- s'il est témoin des mariés.

En tête de chaque jour, des tuiles donnent les présents, les absents, les personnes en attente et les
repas à prévoir : adultes, enfants et prestataires (photographe, vidéaste) présents. Les bébés n'ont pas
de repas et sont comptés à part.

### Un formulaire par fête

Chaque jour de fête peut avoir son formulaire, réglé dans **Réglages → Formulaires**. La fenêtre
montre un compartiment par fête (nom, date, adresse, « Ouvert / Fermé », « Principal »), replié par
défaut ; son chevron déplie tous les réglages de ce formulaire (un seul compartiment ouvert à la fois) :
- ouvert ou fermé (un formulaire fermé affiche « Ce formulaire n'est pas ouvert ») ;
- son adresse, tirée du nom de la fête et modifiable : `https://theryble.github.io/mariage-rsvp/?fete=mariage`,
  `?fete=vin-d-honneur`, `?fete=fete-du-22-aout`… (bouton « Copier le lien » ; deux formulaires ne
  peuvent pas avoir la même adresse) ;
- l'**adresse simple** `theryble.github.io/mariage-rsvp` (celle des QR codes déjà envoyés) ouvre le
  formulaire choisi en haut de la fenêtre, au réglage « Formulaire ouvert par l'adresse simple »
  (bouton « Appliquer ») : le vin d'honneur par défaut, ou tout autre formulaire, ou aucun ;
- tout ce que voit l'invité, rangé en groupes repliables :
  - **Logo et en-tête** : logo (remplacé par une image PNG, JPEG ou SVG, réduite automatiquement, avec
    une version facultative pour le mode sombre ; masqué ; ou logo d'origine), titre de l'onglet,
    sur-titre, titre « Marine & Jeremy » ;
  - **Présentation et encadrés** : texte de présentation, règle « sans accompagnant » (affichée ou non,
    texte), encadrés Dress code et Cadeaux (affichés ou non, titres et textes), pastilles de couleur
    du dress code (nom et couleur, jusqu'à 6, Beige et Doré par défaut, ou aucune) ;
  - **Questions** : titre, réponses « oui » et « non » avec leurs précisions, question du message libre,
    case « sans accompagnant », bouton d'envoi ;
  - **Confirmation et bas de page** : messages pour un invité présent ou absent, bas de page.

  Le nom, la date et les heures viennent de Réglages → Jours de fête. Dans les textes, ces repères sont
  remplacés automatiquement : {Fête} / {fête}, {date}, {jour}, {date chiffres}, {horaire}, {lieu},
  {lieu court} ; **mot** met un mot en gras. « Revenir aux textes d'origine » remet les textes du
  vin d'honneur.

**Code d'accès** : dans le compartiment d'un formulaire, « Protéger ce formulaire par un code » (avec
« Générer un code ») réserve le formulaire aux invités qui ont le code. Ils voient d'abord un écran
« Formulaire protégé » ; le bon code ouvre le formulaire et reste retenu sur leur appareil. La base
vérifie le code (textes et envoi de la réponse) et ne le transmet jamais à la page publique. Les
majuscules et les espaces ne comptent pas. Avant la première utilisation, exécuter
`supabase/code-acces.sql` dans **SQL Editor** (après `invites.sql`).

Le bouton **« Voir le formulaire »** de l'en-tête ouvre la liste des formulaires ouverts (fête, date,
adresse) pour choisir lequel voir.

Le bouton **« Aperçu avant enregistrement »** ouvre le formulaire tel que l'invité le verra avec les
réglages en cours (textes, logo, date limite), en taille téléphone ou ordinateur, sans rien enregistrer
ni envoyer. « Voir le formulaire » montre la version enregistrée.

Sans réglage enregistré, seul le formulaire d'origine du vin d'honneur existe. Une même personne peut
répondre à plusieurs formulaires depuis le même appareil (une réponse par fête). Chaque formulaire a sa
propre date limite des réponses (Réglages → Formulaires), pré-remplie avec l'ancienne date commune
(31 mai 2027) ; la base applique la même règle que la page.

Chaque réponse est ajoutée automatiquement à la liste de sa fête, ou rattachée à l'invité du même nom
s'il existe déjà ; sa cellule porte la mention « Formulaire » et sa présence ce jour-là suit sa
réponse. Pour la retirer de la liste, supprimer d'abord sa réponse dans l'onglet Réponses.

L'onglet **Réponses** sépare les réponses de chaque formulaire : un bouton par formulaire (avec son
nombre de réponses) et, en dessous, un tableau par fête avec son titre et ses chiffres (réponses,
présents, absents). « Tous les formulaires » affiche tous les tableaux l'un sous l'autre ; un formulaire
choisi limite aussi les chiffres du haut, l'export CSV et les destinataires du rappel. La fenêtre **Partager** propose un lien et un QR code par
formulaire ouvert.

**Avant de mettre en ligne cette version**, exécuter `supabase/invites.sql` (après
`date-limite-reglable.sql`) : il ajoute la fête aux réponses et remplace `submit_rsvp`. Ne plus
ré-exécuter `date-limite-reglable.sql` ensuite, il remettrait l'ancienne version de `submit_rsvp`.

Dans chaque jour, les invités sont rangés par compartiment (Les mariés, Témoins, Famille, Amis, Travail,
Accompagnants, Prestataires, Invités), puis par statut (présents, en attente, absents), puis par âge
(adultes, enfants, bébés), puis par ordre alphabétique du prénom.

Les jours de fête (nom, date, heures de début et de fin) se règlent dans **Réglages → Jours de fête** :
on peut en ajouter jusqu'à 6, les renommer, changer leur date et leurs heures, ou en retirer. Les heures
sont facultatives et s'affichent sous le titre de chaque jour dans l'onglet Invités.

**Réglages → Les mariés** garde le prénom et le nom de la mariée et du marié, ainsi que ceux de leurs
enfants (bouton « Ajouter un enfant », jusqu'à 10, avec leur âge : enfant, adulte ou bébé). Ils
apparaissent d'office, présents, dans le compartiment « Les mariés » en tête de chaque jour de fête,
et comptent dans les chiffres et les repas.

Avant la première utilisation, exécuter `supabase/invites.sql` dans **SQL Editor**.

### Dans Supabase

Dans Supabase : **Table Editor** → vue **reponses**. Les réponses y sont triées par nom, avec les dates en heure de Paris.
Le bouton **Export → CSV** télécharge la liste.

Pour compter, dans **SQL Editor** :

```sql
select count(*) filter (where attending) as presents,
       count(*) filter (where not attending) as absents,
       count(*) as total
from rsvps;
```

Pour supprimer une réponse de test : **Table Editor** → table **rsvps** → cocher la ligne → **Delete**.

## Notifications par e-mail

À chaque réponse (nouvelle ou modifiée), chaque compte de `public.admins` reçoit un e-mail avec le nom,
la réponse, le contact, le message et le total des présents et absents. L'envoi passe par
[Resend](https://resend.com) (gratuit jusqu'à 3 000 e-mails par mois).

1. Créer un compte sur <https://resend.com> **avec la même adresse e-mail que ton compte admin Supabase**.
2. **API Keys → Create API Key** : nom `mariage-rsvp`, permission *Sending access*. Copier la clé (`re_…`).
   Elle ne s'affiche qu'une fois.
3. Supabase → **SQL Editor**, exécuter (en remplaçant la clé) :

   ```sql
   select vault.create_secret('re_ta_cle', 'resend_api_key');
   ```

4. Exécuter ensuite tout le contenu de `supabase/notifications.sql`.
5. Envoyer une réponse depuis le formulaire : l'e-mail arrive en quelques secondes (vérifier les spams la
   première fois).

Sans nom de domaine, Resend n'envoie que depuis `onboarding@resend.dev` et seulement vers l'adresse du
compte Resend. Pour prévenir plusieurs administrateurs avec des adresses différentes, il faut vérifier
un nom de domaine dans Resend, puis changer l'adresse dans la fonction `notify_sender()`.

En cas de problème, voir les derniers appels à Resend dans **SQL Editor** :

```sql
select created, status_code, content from net._http_response order by created desc limit 5;
```

Pour changer la clé : `select vault.update_secret((select id from vault.secrets where name = 'resend_api_key'), 're_nouvelle_cle');`
Pour couper les notifications : `drop trigger rsvps_notify on public.rsvps;`

## Bon à savoir

- **Mise en pause** : Supabase met en pause les projets gratuits après 7 jours sans activité. Le workflow
  `keepalive.yml` appelle la base tous les 3 jours pour l'éviter. GitHub désactive les workflows planifiés
  d'un dépôt public après 60 jours sans commit : il prévient par e-mail, et il suffit alors de cliquer sur
  **Enable workflow** dans l'onglet **Actions** du dépôt. Si le projet est malgré tout en pause, le
  réactiver depuis le tableau de bord Supabase (**Restore project**).
- **Modifier une réponse** : l'invité revient sur la page depuis le même appareil et le même navigateur,
  clique sur « Modifier ma réponse », et sa réponse est mise à jour (pas de doublon). « Reçue le » garde
  la date du premier envoi, « Modifiée le » celle du dernier. Depuis un autre appareil, une nouvelle
  réponse est créée : il suffit de supprimer l'ancienne.
- **Robots** : un champ invisible piège les robots qui remplissent automatiquement les formulaires ;
  leurs envois sont ignorés.
- **Confidentialité** : la balise `noindex` demande aux moteurs de recherche de ne pas référencer la page.
- **Date limite** : après le 31 mai 2027 à 23h59 (heure de Paris), une réponse déjà envoyée ne peut plus être modifiée (bloqué par la base, pas seulement par la page). Les nouvelles réponses restent acceptées.
