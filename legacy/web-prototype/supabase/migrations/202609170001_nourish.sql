-- Apply to the user's selected Supabase project only.
-- Account-owned state keeps the existing prototype data shape intact.
create table if not exists public.nourish_state (
 user_id uuid primary key references auth.users(id) on delete cascade,
 data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object' and octet_length(data::text) <= 500000),
 updated_at timestamptz not null default now()
);
alter table public.nourish_state enable row level security;
revoke all on public.nourish_state from anon;
grant select, insert, update, delete on public.nourish_state to authenticated;
create policy "Read own nutrition state" on public.nourish_state for select to authenticated using ((select auth.uid()) = user_id);
create policy "Insert own nutrition state" on public.nourish_state for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Update own nutrition state" on public.nourish_state for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Delete own nutrition state" on public.nourish_state for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.meal_analyses (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 dish_name text not null,
 ingredients jsonb not null default '[]'::jsonb,
 nutrition jsonb not null default '{}'::jsonb,
 source text not null default 'user_confirmed',
 created_at timestamptz not null default now()
);
create index meal_analyses_user_created_idx on public.meal_analyses(user_id, created_at desc);
alter table public.meal_analyses enable row level security;
revoke all on public.meal_analyses from anon;
grant select, insert, update, delete on public.meal_analyses to authenticated;
create policy "Own meal analyses" on public.meal_analyses for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
