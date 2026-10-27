# Mai

Asistente personal en Flutter para Android, Windows y Linux. Chat con IA (Groq) que puede crear tareas, timers y pomodoros, conversación por voz (Whisper + TTS) y una mascota animada.

## Primer uso

1. `flutter pub get`
2. Copia `env.example.json` a `env.json` y rellénalo (ver *Supabase*). Está en `.gitignore`.
3. `flutter run -d <android|windows|linux> --dart-define-from-file=env.json` (VS Code: la configuración "Mai" ya lo incluye).
4. Al abrir la app, inicia sesión con tu cuenta de Supabase (solo la primera vez en cada dispositivo). La sesión se guarda cifrada (Keystore / DPAPI / libsecret).

Sin `env.json` la app funciona en modo local: pide una API key de Groq (gratis en https://console.groq.com/keys) que se guarda en el dispositivo, y no sincroniza.

Requisitos por plataforma:
- **Windows:** activar el Modo desarrollador (`start ms-settings:developers`), Flutter lo necesita para enlazar plugins. Además `flutter_tts` necesita `nuget.exe` en el PATH (`winget install Microsoft.NuGet`).
- **Android:** aceptar licencias con `flutter doctor --android-licenses`. La primera vez que tocas el micrófono, la app pide el permiso de grabar audio.
- **Linux:** `sudo apt install libsecret-1-dev libjsoncpp-dev` para el almacén seguro de la sesión, y `sudo apt install pulseaudio-utils ffmpeg` para la entrada de voz.

## Estructura

- `lib/cerebro/` lógica: servicio de IA, controlador del chat, persistencia, TTS, tareas.
- `lib/modelos/` modelos de datos.
- `lib/screens/`, `lib/widgets/`, `lib/providers/` interfaz.
- `test/` tests de servicios y controlador (`flutter test`).

## Supabase: sincronización y acceso

Mai guarda todo en SQLite local (funciona sin conexión) y lo espeja con Supabase cuando hay red. Es de un solo usuario: solo tu cuenta puede entrar, y la key de Groq vive en Supabase, no en los dispositivos.

1. Supabase > SQL Editor: ejecuta `supabase/0001_schema.sql` y luego `supabase/0002_ignore_stale_writes.sql`.
2. Supabase > Authentication > Users > *Add user* (marca *Auto Confirm User*). Con ese correo y contraseña inicias sesión en la app.
3. Supabase > Authentication > Sign In / Providers: desactiva *Allow new users to sign up*, para que nadie más pueda crear cuenta.
4. Proxy de Groq (Edge Function `supabase/functions/groq`), con la CLI (`npx supabase ...`):
   ```
   npx supabase login
   npx supabase secrets set GROQ_API_KEY=gsk_... --project-ref TU-PROYECTO
   npx supabase functions deploy groq --no-verify-jwt --project-ref TU-PROYECTO
   ```
   Opcional: `OWNER_USER_ID=<uuid de tu usuario>` como secret limita el proxy a esa cuenta.
5. En el menú de la app, "Sincronización" muestra el estado y al tocarlo fuerza una sincronización. "Cerrar sesión" desconecta solo ese dispositivo.

Nunca pongas la `secret key` de Supabase ni la key de Groq en `env.json` ni en la app: solo la URL y la publishable key.
