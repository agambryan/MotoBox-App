# Security Guidelines

## Environment Variables

### ⚠️ IMPORTANT: Never commit .env file!

The `.env` file contains sensitive credentials and should NEVER be committed to version control.

### Setup Instructions

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in your actual Supabase credentials in `.env`

3. The `.env` file is already in `.gitignore` and will not be committed

### What if .env was already committed?

If you accidentally committed `.env` file with real credentials:

1. **Immediately rotate your Supabase keys:**
   - Go to Supabase Dashboard > Settings > API
   - Generate new anon key
   - Update your `.env` file with new keys

2. **Remove from git history:**
   ```bash
   git rm --cached .env
   git commit -m "Remove .env from tracking"
   ```

3. **Consider the old keys compromised** and regenerate them

## Data Encryption

- User data is isolated per user ID
- Local database uses SQLite with user-specific encryption (when implemented)
- Photo paths are validated before storage
- Passwords are never stored locally (handled by Supabase Auth)

## Best Practices

1. Never share your `.env` file
2. Use different credentials for development and production
3. Regularly rotate your API keys
4. Enable Row Level Security (RLS) in Supabase
5. Keep your dependencies up to date
