-- 学习数据云同步（手机 ↔ 平板）
--
-- 设计：只同步「只追加」的学习事实（作答事件、首次接触、测试轮次），
-- 卡片状态由各设备按事件顺序在本地重算，因此两台设备不会互相覆盖。
-- 每行属于一个登录用户，行级安全保证只能读写自己的数据。
-- 在 Supabase 控制台 SQL Editor 中整段执行即可；重复执行是安全的。

-- 作答事件：id 由会话与作答确定性生成，同一次作答在任何设备上都相同。
create table if not exists public.sync_review_events (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  word_id integer not null,
  created_at timestamptz not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- 每个词每天的首次接触，用于新词额度。
create table if not exists public.sync_exposure_events (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  word_id integer not null,
  local_date text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- 测试轮次（打卡、每日记录的来源）。中断后完成的轮次会再次上传，允许更新。
create table if not exists public.sync_test_runs (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null,
  started_at timestamptz not null,
  finished_at timestamptz,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists sync_review_events_pull on public.sync_review_events (user_id, updated_at);
create index if not exists sync_exposure_events_pull on public.sync_exposure_events (user_id, updated_at);
create index if not exists sync_test_runs_pull on public.sync_test_runs (user_id, updated_at);

-- 更新时刷新 updated_at，客户端按它增量拉取。
create or replace function public.sync_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists sync_test_runs_touch on public.sync_test_runs;
create trigger sync_test_runs_touch
  before update on public.sync_test_runs
  for each row execute function public.sync_touch_updated_at();

-- 行级安全：只能读写自己的行；不开放删除。
alter table public.sync_review_events enable row level security;
alter table public.sync_exposure_events enable row level security;
alter table public.sync_test_runs enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['sync_review_events', 'sync_exposure_events', 'sync_test_runs'] loop
    execute format('drop policy if exists "own rows select" on public.%I', t);
    execute format('drop policy if exists "own rows insert" on public.%I', t);
    execute format('drop policy if exists "own rows update" on public.%I', t);
    execute format(
      'create policy "own rows select" on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format(
      'create policy "own rows insert" on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format(
      'create policy "own rows update" on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
  end loop;
end;
$$;
