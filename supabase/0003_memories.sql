-- Memoria personal de Mai: datos que el usuario le pide recordar.
-- Mismo esquema de sincronización que 0001 (RLS por usuario, cursor del
-- servidor, borrado lógico) y la protección de 0002. Pégalo en SQL Editor > Run.

create table if not exists public.memories (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  text              text not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  server_updated_at timestamptz not null default now(),
  deleted_at        timestamptz
);

create index if not exists memories_sync_idx on public.memories (user_id, server_updated_at);

drop trigger if exists memories_touch on public.memories;
create trigger memories_touch before insert or update on public.memories
  for each row execute function public.touch_server_updated_at();

drop trigger if exists a_memories_stale_guard on public.memories;
create trigger a_memories_stale_guard before update on public.memories
  for each row execute function public.ignore_stale_writes();

alter table public.memories enable row level security;

drop policy if exists memories_own_rows on public.memories;
create policy memories_own_rows on public.memories
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
