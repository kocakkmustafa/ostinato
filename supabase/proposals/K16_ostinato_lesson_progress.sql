-- ============================================================================
-- ÖNERİ — UYGULANMADI. K16 ilerleme senkronu (Ostinato), 2026-11-01.
--
-- Bu dosya bir migration DEĞİLDİR ve hiçbir Supabase projesine uygulanmamıştır.
-- Hedef proje (ortak Motion, `aljdbngmeqwmsqhvfeau`), migration'ın hangi
-- repodan (Core `supabase/migrations/` ya da app) gideceği ve canlı uygulama
-- kurucu onayı bekler. Tasarım: docs/sync/K16-ilerleme-senkronu.md
--
-- Yalnız gitar kursu ders ilerlemesi taşınır. Ses, video, ham ölçüm, seans
-- özeti, ayar yok. Birleşme kuralı istemcideki
-- lib/app/sync/lesson_progress_sync.dart ile aynıdır:
--   seen_at = en erken, practiced_at = en geç, completed_at = en erken (monoton),
--   practice_counts = kopya başına max (G-Counter; toplam = değerlerin toplamı).
-- ============================================================================

-- practice_counts: {"<replica-uuid>": <0..100000>, ...}, en çok 16 kopya.
create or replace function public.ostinato_valid_practice_counts(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p) = 'object'
     and (select count(*) from jsonb_object_keys(p)) <= 16
     and not exists (
       select 1
       from jsonb_each(p) as e(k, v)
       where e.k !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          or jsonb_typeof(e.v) <> 'number'
          or (e.v #>> '{}') !~ '^[0-9]{1,6}$'
          or (e.v #>> '{}')::integer > 100000
     );
$$;

create table public.ostinato_lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_version text not null check (
    char_length(content_version) between 1 and 128
    and position('|' in content_version) = 0
  ),
  lesson_id text not null check (
    char_length(lesson_id) between 1 and 128
    and position('|' in lesson_id) = 0
  ),
  seen_at timestamptz,
  practiced_at timestamptz,
  completed_at timestamptz,
  practice_counts jsonb not null default '{}'::jsonb
    check (public.ostinato_valid_practice_counts(practice_counts)),
  server_updated_at timestamptz not null default now(),
  primary key (user_id, content_version, lesson_id),
  -- Yerel kuralla aynı: pratik olmadan kullanıcı beyanıyla tamamlama yok.
  constraint ostinato_lesson_progress_completion_needs_practice
    check (completed_at is null or practice_counts <> '{}'::jsonb)
);

create index ostinato_lesson_progress_pull_idx
  on public.ostinato_lesson_progress (user_id, server_updated_at);

alter table public.ostinato_lesson_progress enable row level security;

-- İstemci yalnız KENDİ satırını okur ve silebilir ("sunucudaki ilerlemeyi
-- sil"). Doğrudan insert/update yok: yazma yalnız birleştiren RPC ile.
create policy ostinato_lesson_progress_select_own
  on public.ostinato_lesson_progress for select to authenticated
  using ((select auth.uid()) = user_id);
create policy ostinato_lesson_progress_delete_own
  on public.ostinato_lesson_progress for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.ostinato_lesson_progress from anon, authenticated;
grant select, delete on public.ostinato_lesson_progress to authenticated;
grant select, insert, update, delete
  on public.ostinato_lesson_progress to service_role;

-- Kopya başına max birleşmesi.
create or replace function public.ostinato_merge_practice_counts(a jsonb, b jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    jsonb_object_agg(
      k,
      greatest(
        coalesce((a ->> k)::integer, 0),
        coalesce((b ->> k)::integer, 0)
      )
    ),
    '{}'::jsonb
  )
  from (
    select jsonb_object_keys(coalesce(a, '{}'::jsonb)) as k
    union
    select jsonb_object_keys(coalesce(b, '{}'::jsonb))
  ) as keys;
$$;

-- Sunucu saatinden ileri tarihleri kırpar; NULL'u korur (LEAST NULL'u yok
-- saydığı için düz least(x, now()) NULL'u now()'a çevirirdi).
create or replace function public.ostinato_clamp_to_now(p timestamptz)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case when p is null then null else least(p, now()) end;
$$;

-- Tek yazma yolu. Son yazan kazanmaz: her alan §3 kuralıyla birleşir, bu yüzden
-- tekrar, gecikme ve sıra sonucu değiştirmez (idempotent).
create or replace function public.ostinato_push_lesson_progress(p_records jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'ostinato_sync_requires_account' using errcode = '42501';
  end if;
  -- Veli onayı bekleyen/engelli hesap: hesap özellikleri kapalı (Core kuralı).
  if public.motion_account_restricted(v_uid) then
    raise exception 'ostinato_sync_account_restricted' using errcode = '42501';
  end if;
  if jsonb_typeof(p_records) is distinct from 'array'
     or jsonb_array_length(p_records) > 500 then
    raise exception 'ostinato_sync_batch_invalid' using errcode = '22023';
  end if;
  -- Aynı anahtar bir partide iki kez gelirse ON CONFLICT aynı satırı iki kez
  -- günceller ve hata verir; istemci kirli kümeyi zaten tekilleştirir.
  if (
    select count(*) <> count(distinct (r ->> 'content_version', r ->> 'lesson_id'))
    from jsonb_array_elements(p_records) as r
  ) then
    raise exception 'ostinato_sync_duplicate_key' using errcode = '22023';
  end if;

  insert into public.ostinato_lesson_progress as t (
    user_id, content_version, lesson_id,
    seen_at, practiced_at, completed_at, practice_counts
  )
  select
    v_uid, r.content_version, r.lesson_id,
    public.ostinato_clamp_to_now(r.seen_at),
    public.ostinato_clamp_to_now(r.practiced_at),
    public.ostinato_clamp_to_now(r.completed_at),
    coalesce(r.practice_counts, '{}'::jsonb)
  from jsonb_to_recordset(p_records) as r (
    content_version text,
    lesson_id text,
    seen_at timestamptz,
    practiced_at timestamptz,
    completed_at timestamptz,
    practice_counts jsonb
  )
  on conflict (user_id, content_version, lesson_id) do update set
    seen_at = least(t.seen_at, excluded.seen_at),
    practiced_at = greatest(t.practiced_at, excluded.practiced_at),
    completed_at = least(t.completed_at, excluded.completed_at),
    practice_counts = public.ostinato_merge_practice_counts(
      t.practice_counts, excluded.practice_counts
    ),
    server_updated_at = now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ostinato_valid_practice_counts kasıtlı olarak herkese açık kalır: CHECK
-- kısıtı yazan rolün yetkisiyle değerlendirilir (service_role dahil) ve
-- fonksiyon yalnız saf bir doğrulayıcıdır.
revoke all on function public.ostinato_merge_practice_counts(jsonb, jsonb) from public;
revoke all on function public.ostinato_clamp_to_now(timestamptz) from public;
revoke all on function public.ostinato_push_lesson_progress(jsonb) from public;
grant execute on function public.ostinato_push_lesson_progress(jsonb)
  to authenticated;

-- Çekme (istemci, RLS ile):
--   select content_version, lesson_id, seen_at, practiced_at, completed_at,
--          practice_counts, server_updated_at
--   from public.ostinato_lesson_progress
--   where server_updated_at > :cursor - interval '5 minutes';
-- Örtüşme penceresi, geç commit olan işlemleri kaçırmamak içindir; birleşme
-- idempotent olduğu için tekrar gelen satır zararsızdır.
--
-- Hesap silme: Core `motion-delete-account` → auth.admin.deleteUser →
-- on delete cascade. Ek fonksiyon gerekmez.
