# Migrations de la Base de Données

Toutes les migrations actives du projet sont désormais hébergées dans le dossier [`backend/supabase/migrations`](../supabase/migrations) au format standard **Supabase / PostgreSQL**.

- **Appliquer les migrations sur Supabase** : `npm run migrate`
- **Initialiser les données de démonstration** : `npm run seed`

Le dossier `legacy_mysql/` contient l'historique des anciennes migrations MySQL archivées à titre de référence.
