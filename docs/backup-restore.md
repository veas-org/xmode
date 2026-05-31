# Backup And Restore

Back up:

- production PostgreSQL databases
- `/rails/storage`
- `.kamal/secrets` source values in a password manager
- provider app credentials

Restore:

1. Restore PostgreSQL databases.
2. Restore `/rails/storage`.
3. Recreate secrets.
4. Deploy the same or newer xmode image.
5. Run `bin/rails db:prepare`.
