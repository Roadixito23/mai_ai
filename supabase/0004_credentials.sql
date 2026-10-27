-- Cambio de usuario y contraseña desde la app.
--
-- Mai inicia sesión con "usuario + contraseña", pero Supabase Auth identifica
-- por correo: el usuario se guarda como `<usuario>@mai.local` (nunca se envía
-- nada a esa dirección). Cambiar el correo con `updateUser` pediría confirmarlo
-- por email, así que el cambio va por esta función, que exige la contraseña
-- actual y solo toca al usuario de la sesión.

create or replace function public.change_credentials(
  current_password text,
  new_username text,
  new_password text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  uname text := trim(new_username);
  new_email text := lower(trim(new_username)) || '@mai.local';
begin
  if uid is null then
    raise exception 'Sin sesión.' using errcode = '28000';
  end if;
  if lower(uname) !~ '^[a-z0-9._-]{3,32}$' then
    raise exception 'Usuario inválido: 3 a 32 caracteres (letras, números, . _ -).' using errcode = '22023';
  end if;
  if length(new_password) < 6 then
    raise exception 'La contraseña debe tener al menos 6 caracteres.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from auth.users
    where id = uid and encrypted_password = extensions.crypt(current_password, encrypted_password)
  ) then
    raise exception 'La contraseña actual no es correcta.' using errcode = '28P01';
  end if;

  update auth.users
     set email = new_email,
         encrypted_password = extensions.crypt(new_password, extensions.gen_salt('bf')),
         raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('username', uname),
         updated_at = now()
   where id = uid;

  update auth.identities
     set identity_data = identity_data || jsonb_build_object('email', new_email),
         updated_at = now()
   where user_id = uid and provider = 'email';
end;
$$;

revoke all on function public.change_credentials(text, text, text) from public, anon;
grant execute on function public.change_credentials(text, text, text) to authenticated;
