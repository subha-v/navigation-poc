# Supabase Configuration

## Setup Instructions

1. **Copy the template file**:
   ```bash
   cp SupabaseConfig.template.swift SupabaseConfig.swift
   ```

2. **Edit SupabaseConfig.swift** and add your Supabase credentials:
   - Replace `YOUR_PROJECT` with your Supabase project ID
   - Replace `YOUR_ANON_KEY` with your Supabase anon key

3. **Verify .gitignore**: The actual `SupabaseConfig.swift` file is already added to `.gitignore` to prevent accidental commits.

## Security Notes

- **NEVER** commit `SupabaseConfig.swift` to version control
- The template file (`SupabaseConfig.template.swift`) is safe to commit
- Keep your credentials secure and rotate them if exposed
- For production, consider using environment variables or a secure key management system

## Getting Your Supabase Credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to Settings > API
4. Copy:
   - Project URL (for `url`)
   - Anon/Public key (for `anonKey`)