# Making the ICU Case Simulator online — Supabase setup (one-time)

You do these steps once. When you're done, send me two values (Project URL +
anon key) and I'll wire the app up against them. Nothing here is a secret you
need to hide — the anon key is meant to live in frontend code; security is
enforced by the Row-Level-Security policies in `schema.sql`.

## 1. Create the project (free)
1. Go to https://supabase.com and sign up (GitHub login works).
2. Click **New project**. Pick any name (e.g. `icu-case-simulator`), a strong
   database password (save it somewhere; you rarely need it), and the region
   closest to your students.
3. Wait ~2 minutes for it to finish provisioning.

## 2. Create the database tables
1. In the project, open **SQL Editor** (left sidebar) → **New query**.
2. Open `supabase/schema.sql` from this repo, copy its entire contents, paste
   into the query box, and click **Run**. You should see "Success".

## 3. Choose how sign-up works (email confirmation)
- Go to **Authentication → Providers → Email**.
- For a classroom, it's usually easiest to turn **"Confirm email" OFF** so
  students can sign up and start immediately without clicking a link in their
  inbox. (Leave it ON if you'd rather require a verified email.)
- Leave Email provider **enabled**.

## 4. Grab the two values I need
- Go to **Project Settings → API**.
- Copy the **Project URL** (looks like `https://xxxxxxxx.supabase.co`).
- Copy the **anon / public** key (a long string labelled `anon` `public`).
- Send me both. That's it — I'll do the rest.

## 5. (Later) Make yourself the instructor
After you've signed up inside the app once, come back to **SQL Editor** and run:

```sql
update public.profiles set role = 'instructor'
where id = (select id from auth.users where email = 'YOUR_EMAIL_HERE');
```

That flips your account to the instructor role so you'll see the dashboard
(Phase 2). Students stay on the default `student` role automatically.
