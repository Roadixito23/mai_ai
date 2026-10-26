-- Esquema inicial de Mai. Pégalo en Supabase > SQL Editor > Run.
--
-- Cada fila pertenece a un usuario (user_id) y RLS garantiza que solo él la ve.
-- Sincronización: el cliente escribe `updated_at` (gana el más reciente) y baja
-- cambios con `server_updated_at`, un cursor que pone el servidor y siempre crece.
-- Los borrados son lógicos (`deleted_at`) para que otros dispositivos se enteren.

create extension if not exists pgcrypto;

-- Mantiene el cursor de sincronización en cada insert/update.
create or replace function public.touch_server_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- tareas
create table if not exists public.tasks (
  id                   uuid primary key,
  user_id              uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title                text not null,
  date                 date not null,
  is_completed         boolean not null default false,
  pomodoros_completed  integer not null default 0,
  estimated_pomodoros  integer not null default 1,
  updated_at           timestamptz not null default now(),
  server_updated_at    timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ---------------------------------------------------------- temporizadores
create table if not exists public.timers (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  label             text not null,
  kind              text not null check (kind in ('custom', 'pomodoroWork', 'pomodoroBreak')),
  duration_seconds  integer not null check (duration_seconds > 0),
  status            text not null check (status in ('running', 'paused', 'done')),
  ends_at           timestamptz,
  remaining_seconds integer,
  task_id           uuid,
  task_date         date,
  handled           boolean not null default false,
  updated_at        timestamptz not null default now(),
  server_updated_at timestamptz not null default now(),
  deleted_at        timestamptz
);

-- ------------------------------------------------------------------ chat
create table if not exists public.messages (
  id                uuid primary key,
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  text              text not null,
  is_user           boolean not null,
  model_id          text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  server_updated_at timestamptz not null default now(),
  deleted_at        timestamptz
);

-- ----------------------------------------------- índices, triggers y RLS
do $$
declare
  t text;
begin
  foreach t in array array['tasks', 'timers', 'messages'] loop
    execute format(
      'create index if not exists %I on public.%I (user_id, server_updated_at)',
      t || '_sync_idx', t
    );

    execute format('drop trigger if exists %I on public.%I', t || '_touch', t);
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.touch_server_updated_at()',
      t || '_touch', t
    );

    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t || '_own_rows', t);
    execute format(
      'create policy %I on public.%I
         for all to authenticated
         using (user_id = (select auth.uid()))
         with check (user_id = (select auth.uid()))',
      t || '_own_rows', t
    );
  end loop;
end
$$;
