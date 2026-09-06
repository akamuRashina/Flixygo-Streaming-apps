# FlixyGo → Supabase migration notes

This version is matched against your real `schema.sql` (not a guessed
schema) — table/column names below are exactly what the rewritten
services query.

## 1. Keeping the URL / anon key private

Recommended approach: **`--dart-define-from-file`**. No extra package,
nothing bundled as a plaintext asset, one JSON file that never gets
committed.

1. Copy `supabase-keys.example.json` → `supabase-keys.json` and fill in
   your real project URL + anon key (Supabase dashboard → Project
   Settings → API).
2. Add this line to `.gitignore`:
   ```
   supabase-keys.json
   ```
3. Run / build with the file:
   ```bash
   flutter run --dart-define-from-file=supabase-keys.json
   flutter build apk --dart-define-from-file=supabase-keys.json
   flutter build ios --dart-define-from-file=supabase-keys.json
   ```
   VS Code: add `"args": ["--dart-define-from-file=supabase-keys.json"]`
   to your launch config. Android Studio: same flag under "Additional
   run args".

**Note on "private":** the anon key is *meant* to be shipped inside a
client app (Supabase's own docs say so) — it's still extractable from a
compiled binary if someone really wants it. The actual security
boundary is your RLS policies (already in schema.sql), not hiding this
key. What `--dart-define-from-file` buys you is keeping it out of your
**git history**, which is what you asked for.

## 2. What changed in the code

- `lib/env.dart` — new, reads the two keys via `String.fromEnvironment`.
- `lib/main.dart` — calls `Supabase.initialize()` before `runApp`.
- `lib/services/api_client.dart` — stripped to just `ApiException` +
  `wrapSupabaseError()`. Kept under this filename on purpose so
  `login_page.dart`, `movie_detail_page.dart`, and
  `anime_kdrama_detail_page.dart` don't need any edits.
- `auth_service.dart`, `content_service.dart`, `stream_service.dart`,
  `bookmark_service.dart`, `comment_service.dart`,
  `watch_history_service.dart` — rewritten to call Supabase directly.
  Public method signatures are unchanged, so no page-level UI code
  needed edits either.

`cache_service.dart`, `settings_service.dart`, `profile_photo_service.dart`,
`app_lock_service.dart` are untouched — they were already local-only.

## 3. Gotchas specific to your schema

- **Episodes are two separate tables.** `anime_episodes` (keyed by
  `anime_slug`) and `kdrama_episodes` (keyed by `kdrama_slug`) — not one
  shared table with a `content_type` column. `content_service.dart` and
  `stream_service.dart` branch on `ContentType` to pick the right one.
- **`comments` has no `username` column.** It only stores `user_id`.
  `comment_service.dart` embeds `profiles(username)` via the FK
  (`user_id references profiles(id)`) when listing, and doesn't try to
  write a username on insert.
- **`watch_history`'s uniqueness is a functional index**
  (`unique (user_id, content_type, content_slug, coalesce(episode_slug,''))`),
  not a plain column-list constraint. Postgrest's `upsert(onConflict:)`
  can only target literal columns, so it can't resolve against this
  index. `watch_history_service.update()` does a manual
  select-then-insert/update instead of `upsert()`.
- **`bookmarks`' primary key is the autoincrement `id`**, not the
  natural `(user_id, content_type, content_slug)` key. `upsert()` there
  needs `onConflict: 'user_id,content_type,content_slug'` explicitly —
  already wired up — otherwise every "save" would insert a fresh
  duplicate row instead of updating.
- **No popularity/view-count column anywhere.** The "Populer" section
  (`HomeFeed.popularAll`) currently just orders by `updated_at` ascending
  as a placeholder so it isn't an exact duplicate of "Terbaru" — it's
  not a real ranking. If you want a genuine popularity metric, add e.g.
  `views int default 0` to `movies`/`anime`/`kdrama`, bump it on detail
  page loads, and I'll swap the `order()` call in
  `content_service.dart`'s `_fetchPopular()`.
- **Movies have both `stream_url` and `embed_url`.** `getDetail()` now
  prefers `stream_url` and falls back to `embed_url` if that's empty.

## 4. Auth note

Supabase Auth needs an email; your login screen only asks for a
username. `auth_service.dart` fakes one as `username@flixygo.local` and
passes `data: {'username': ...}` to `signUp()` — your schema's
`handle_new_user()` trigger picks that up from
`raw_user_meta_data ->> 'username'` and creates the matching `profiles`
row automatically, so this lines up with what you already built.

Two things to check in your Supabase dashboard:

- **Authentication → Providers → Email → "Confirm email"**: turn this
  **off**, otherwise `signUp()` won't return a session and users won't
  be logged in immediately after registering (matching your old
  backend's behavior). `register()` throws an `ApiException` telling
  the user this if it happens.
- Your `profiles.username` column is `unique` — if someone re-registers
  an existing username, Postgres will raise a unique-violation and
  `auth_service.dart` surfaces it as "Username sudah dipakai."

## 5. Profile photos (Supabase Storage)

Profile photos now live in Storage instead of only on-device. Run this
once in the Supabase SQL editor:

```sql
-- 1. Column to cache the public URL on the profile
alter table profiles add column if not exists avatar_url text;

-- 1b. IMPORTANT: schema.sql only gave `profiles` a SELECT policy — there's
--     no UPDATE policy, so writes to avatar_url get silently dropped by
--     RLS (Postgrest returns success with 0 rows affected, no error).
--     This policy is required for the photo upload to actually persist:
create policy "users can update their own profile" on profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- 2. Public bucket for avatars
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- 3. Storage policies — anyone can view, but each user can only
--    upload/update/delete inside their own `<uid>/...` folder.
create policy "Avatar images are publicly accessible"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
on storage.objects for insert
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update their own avatar"
on storage.objects for update
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete their own avatar"
on storage.objects for delete
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
```

What changed in the app:

- `profile_photo_service.dart` — now uploads to the `avatars` bucket at
  `<user_id>/avatar.<ext>` (via `uploadBinary`, so it works on
  Windows/desktop/web where `file_picker` may not return a `.path`),
  and caches the public URL on `profiles.avatar_url`. `getPhotoUrl()`
  reads that column; `clearPhoto()` best-effort removes common
  extensions from Storage and nulls the column.
- `home_page.dart`, `profile_page.dart`, `video_player_page.dart` — all
  switched from `FileImage(File(localPath))` to `NetworkImage(url)`,
  since the photo is no longer local-only.
- `comment_service.dart` now also embeds `profiles(..., avatar_url)`,
  and `video_player_page.dart`'s comment list shows each commenter's
  *own* avatar (previously only your own comments got a photo — everyone
  else always showed the fallback-letter circle).

One behavior change worth knowing: since the URL is cache-busted with a
timestamp query param on every upload, if a user changes their photo,
old cached copies of the previous URL elsewhere in the app just won't
match anymore — that's expected, not a bug.

## 6. One thing I couldn't verify

I don't have read access to your actual Supabase project (just the
`schema.sql` file), so I can't confirm things like: whether RLS is
actually *enabled* on tables beyond what schema.sql shows, whether your
`qualities` jsonb column on episodes really matches the shape
`StreamQuality.fromJson` expects (`quality`, `server`, `stream_url`,
`embed_url`, `subtitle_url` per entry), or whether `genres` is really
stored as a Postgres `text[]` everywhere. If any of those turn out
different, the mismatch will surface immediately as a
`PostgrestException` or a null/empty field on first run — paste me the
error and I'll adjust the matching service.
