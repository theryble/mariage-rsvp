# Inscription au vin d'honneur — Marine & Jeremy

Page d'inscription au vin d'honneur du 22 août 2027 (17h15 – 19h, Manoir des Lys, Auchel).
La page est hébergée sur GitHub Pages et les réponses arrivent dans une feuille Google Sheets.
Les invités n'ont besoin d'aucun compte.

```
index.html                    la page du formulaire
assets/                       logos (clair et sombre)
google-apps-script/Code.gs    le script qui enregistre les réponses dans la feuille
```

## Étape 1 — Créer la feuille de réponses

1. Ouvrir <https://sheets.new> (connecté à ton compte Google).
2. Nommer la feuille, par exemple « Mariage — Réponses vin d'honneur ».
3. Menu **Extensions → Apps Script**.
4. Effacer le contenu de `Code.gs` dans l'éditeur et coller celui de `google-apps-script/Code.gs`.
5. Cliquer sur l'icône **Enregistrer**.

## Étape 2 — Publier le script comme application Web

1. En haut à droite : **Déployer → Nouveau déploiement**.
2. Roue dentée à côté de « Sélectionner le type » → **Application Web**.
3. Régler :
   - **Exécuter en tant que** : Moi
   - **Qui a accès** : Tout le monde
4. **Déployer**, puis **Autoriser l'accès** et choisir ton compte Google.
   Google affiche « Google n'a pas validé cette application » : cliquer sur **Paramètres avancés → Accéder à … (non sécurisé)**. C'est normal pour un script personnel.
5. Copier l'**URL de l'application Web** (elle se termine par `/exec`).
6. Dans `index.html`, coller cette adresse entre les guillemets :

   ```js
   const SCRIPT_URL = 'https://script.google.com/macros/s/…/exec';
   ```

Pour vérifier : ouvrir l'adresse `/exec` dans le navigateur doit afficher `{"ok":true,"service":"rsvp-marine-jeremy"}`.

> Si tu modifies `Code.gs` plus tard : **Déployer → Gérer les déploiements → crayon → Version : Nouvelle version → Déployer**. L'adresse reste la même.

## Étape 3 — Mettre la page en ligne avec GitHub Pages

1. Sur <https://github.com/new>, créer un dépôt **public** (par exemple `mariage-rsvp`), sans README.
2. Dans ce dossier :

   ```sh
   git add .
   git commit -m "Formulaire d'inscription au vin d'honneur"
   git branch -M main
   git remote add origin https://github.com/<ton-pseudo>/mariage-rsvp.git
   git push -u origin main
   ```

3. Sur GitHub : **Settings → Pages → Build and deployment → Source : Deploy from a branch**, branche `main`, dossier `/ (root)` → **Save**.
4. Après une ou deux minutes, la page est en ligne à l'adresse
   `https://<ton-pseudo>.github.io/mariage-rsvp/`.

## Lire les réponses

Tout arrive dans l'onglet **Réponses** de la feuille Google : prénom, nom, présence, contact, message, date de réception et date de modification.
Pour compter les présents, dans une cellule libre : `=NB.SI(D:D;"Présent(e)")`.

## Bon à savoir

- **Modifier une réponse** : « Reçue le » garde la date du premier envoi, « Modifiée le » celle du dernier. L'invité revient sur la page depuis le même appareil et le même navigateur, clique sur « Modifier ma réponse », et sa ligne est mise à jour (pas de doublon). Depuis un autre appareil, une nouvelle ligne est créée : il suffit de supprimer l'ancienne dans la feuille.
- **Confidentialité** : la page est publique, mais les réponses ne sont visibles que dans ta feuille Google. La balise `noindex` demande aux moteurs de recherche de ne pas référencer la page.
- **Robots** : un champ invisible piège les robots qui remplissent automatiquement les formulaires ; leurs envois sont ignorés.
- **Date limite** : le 31 mai 2027 est affiché, mais le formulaire reste ouvert après cette date.
