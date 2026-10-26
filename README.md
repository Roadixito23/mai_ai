# Mai

Asistente personal en Flutter para Android, Windows y Linux. Chat con Gemini, voz (TTS), tareas con Pomodoro y una mascota animada.

## Primer uso

1. `flutter pub get`
2. Copia `env.example.json` a `env.json` y rellénalo (ver *Sincronización*). Está en `.gitignore`.
3. `flutter run -d <android|windows|linux> --dart-define-from-file=env.json` (VS Code: la configuración "Mai" ya lo incluye).
4. Al abrir la app, pega tu API key de Gemini (gratis en https://aistudio.google.com/app/apikey). Se guarda cifrada en el dispositivo (Keystore / DPAPI / libsecret) y se puede cambiar desde el menú.

Requisitos por plataforma:
- **Windows:** activar el Modo desarrollador (`start ms-settings:developers`), Flutter lo necesita para enlazar plugins. Además `flutter_tts` necesita `nuget.exe` en el PATH (`winget install Microsoft.NuGet`).
- **Android:** aceptar licencias con `flutter doctor --android-licenses`.
- **Linux:** `sudo apt install libsecret-1-dev libjsoncpp-dev` para el almacén seguro de la key.

## Estructura

- `lib/cerebro/` lógica: servicio de IA, controlador del chat, persistencia, TTS, tareas.
- `lib/modelos/` modelos de datos.
- `lib/screens/`, `lib/widgets/`, `lib/providers/` interfaz.
- `test/` tests de servicios y controlador (`flutter test`).

## Sincronización (Supabase)

Mai guarda todo en SQLite local (funciona sin conexión) y lo espeja con Supabase cuando hay red. Al ser de un solo usuario no hay pantalla de login: la app entra sola con una cuenta tuya.

1. Supabase > SQL Editor: ejecuta `supabase/0001_schema.sql` y luego `supabase/0002_ignore_stale_writes.sql`.
2. Supabase > Authentication > Users > *Add user* (marca *Auto Confirm User*). Pon ese correo y contraseña en `OWNER_EMAIL` / `OWNER_PASSWORD` de `env.json`.
3. En el menú de la app, "Sincronización" muestra el estado y al tocarlo fuerza una sincronización.

Nunca pongas la `secret key` de Supabase en `env.json` ni en la app: solo la URL y la publishable key.
