# Supabase

The backend connects to Supabase through its PostgreSQL connection string; it
does not expose Supabase credentials to the Flutter client.

1. Copy `backend/.env.example` to `backend/.env`.
2. Set `SUPABASE_DB_URL` to the connection string shown in the Supabase project
   settings under **Database**. URL-encode special characters in the password.
3. From `backend`, run `npm install` and `npm run migrate` to create the schema.
   Use a direct or session-mode connection for schema setup.
4. Start the API with `npm start`.

`schema.sql` is the PostgreSQL schema used by the migration command. The
existing files in `backend/migrations` are legacy MySQL migrations and are not
executed by this command.

To copy existing records, set `MYSQL_SOURCE_URL` to the old MySQL connection
URL and run `npm run migrate:data` from `backend` after applying the schema.
The transfer is ordered by foreign-key dependencies, uses batches, preserves
primary keys, and does not overwrite rows already present in Supabase. Back up
both databases first and review the output; tables missing from the source are
reported and skipped. Before copying any rows, the script verifies that each
present source table exists in Supabase and that all source columns have a
destination. If that check fails, resolve the schema mismatch and rerun it.
Run the transfer before directing production traffic to the new database.

The backend still manages its own `auth_users` accounts and JWTs. Supabase
database credentials must remain server-side and must never be added to the
Flutter application.
