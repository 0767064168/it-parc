# Configuration Supabase (PostgreSQL)

Le backend fonctionne à 100% avec Supabase (PostgreSQL). La base de données et les migrations sont nativement au format Supabase.
Le client Flutter communique exclusivement avec l'API Node.js/Express, les identifiants Supabase ne sont jamais exposés côté client.

## 1. Structure

- **`supabase/migrations/`** : Migrations SQL séquentielles standard Supabase (ex: `20261021000001_initial_schema.sql`).
- **`supabase/schema.sql`** : Schéma global de référence PostgreSQL / Supabase.
- **`supabase/seed.sql`** : Données initiales et de démonstration prêtes pour Supabase (utilisateurs, équipements, tickets, conformité, SLA, etc.).

## 2. Configuration (`.env`)

1. Copiez `backend/.env.example` vers `backend/.env`.
2. Dans le tableau de bord Supabase : **Project Settings > Database > Connection string (URI)**.
3. Renseignez `SUPABASE_DB_URL` dans `.env` :
   ```dotenv
   SUPABASE_DB_URL=postgresql://postgres:[MOT_DE_PASSE]@db.[PROJECT_REF].supabase.co:5432/postgres
   DB_SSL=true
   ```
   *Astuce : Si votre mot de passe contient des caractères spéciaux, veillez à les encoder en URL.*

## 3. Commandes

Depuis le dossier `backend` :

```bash
# 1. Appliquer toutes les migrations Supabase
npm run migrate

# 2. Insérer les données de démonstration dans Supabase
npm run seed

# 3. Lancer l'API
npm start
```

## 4. Migration de données historiques (optionnel)

Si vous avez d'anciennes données MySQL à rapatrier vers Supabase :
1. Renseignez `MYSQL_SOURCE_URL` dans votre `.env`.
2. Exécutez :
   ```bash
   npm run migrate:data
   ```
Les clés primaires et l'intégrité relationnelle sont préservées, et les compteurs de séquence (`IDENTITY`) sont automatiquement resynchronisés.
