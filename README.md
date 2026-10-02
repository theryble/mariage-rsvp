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
- **Date limite** : le 31 mai 2027 est affiché, mais le formulaire reste ouvert après cette date.
