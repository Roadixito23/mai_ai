-- Protección extra: si llega una escritura más vieja que la que ya hay en el
-- servidor (por ejemplo, un dispositivo que estuvo sin red mucho tiempo), se
-- ignora en vez de pisar la versión más reciente. Pégalo en SQL Editor > Run.

create or replace function public.ignore_stale_writes()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at < old.updated_at then
    return null; -- cancela este UPDATE para esa fila
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['tasks', 'timers', 'messages'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_stale_guard', t);
    -- El nombre empieza con "a" para que corra antes que *_touch (orden alfabético).
    execute format('drop trigger if exists %I on public.%I', 'a_' || t || '_stale_guard', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.ignore_stale_writes()',
      'a_' || t || '_stale_guard', t
    );
  end loop;
end
$$;
