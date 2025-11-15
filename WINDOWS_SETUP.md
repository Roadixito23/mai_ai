# Guía de Configuración - Asistente de Voz Mai (Windows)

Esta guía te ayudará a configurar y usar el asistente de voz de Mai en Windows Desktop.

## 📋 Prerequisitos

### 1. Flutter para Windows Desktop

Asegúrate de tener Flutter instalado y configurado para Windows Desktop:

```bash
flutter doctor
```

Debes ver una marca verde (✓) en "Windows Version".

Si no está habilitado, ejecuta:

```bash
flutter config --enable-windows-desktop
```

### 2. Configuración de Windows

#### Habilitar Reconocimiento de Voz en Windows

1. **Abrir Configuración de Windows**
   - Presiona `Win + I`
   - Ve a `Privacidad y seguridad` → `Micrófono`
   - Asegúrate de que "Acceso al micrófono" esté **activado**
   - Habilita el acceso al micrófono para aplicaciones de escritorio

2. **Configurar Reconocimiento de Voz**
   - Ve a `Configuración` → `Hora e idioma` → `Voz`
   - En "Micrófono", haz clic en "Comenzar"
   - Sigue el asistente para configurar tu micrófono

#### Instalar Voces en Español

Windows necesita tener voces en español instaladas para Text-to-Speech:

1. **Abrir Configuración de Voz**
   - Presiona `Win + I`
   - Ve a `Hora e idioma` → `Idioma y región`
   - Haz clic en `Agregar un idioma`

2. **Instalar Español**
   - Busca "Español (España)" o "Español (México)"
   - Selecciónalo y haz clic en `Siguiente`
   - Marca las opciones:
     - ✅ Instalar paquete de idioma
     - ✅ Texto a voz
     - ✅ Reconocimiento de voz
   - Haz clic en `Instalar`

3. **Verificar Voces Instaladas**
   - Ve a `Configuración` → `Hora e idioma` → `Voz`
   - En "Voz", deberías ver voces en español disponibles
   - Ejemplos: "Microsoft Helena", "Microsoft Sabina", etc.

### 3. Verificar Micrófono

1. **Probar Micrófono**
   - Abre la aplicación "Grabadora de voz" de Windows
   - Intenta grabar y reproducir audio
   - Si funciona, tu micrófono está configurado correctamente

2. **Ajustar Volumen**
   - Click derecho en el icono de volumen en la barra de tareas
   - Selecciona "Configuración de sonido"
   - Ve a "Entrada" y ajusta el volumen del micrófono

## 🚀 Instalación

### 1. Instalar Dependencias

En el directorio del proyecto, ejecuta:

```bash
flutter pub get
```

Esto instalará automáticamente:
- `speech_to_text` - Para reconocimiento de voz
- `flutter_tts` - Para síntesis de voz
- `permission_handler` - Para gestión de permisos

### 2. Compilar y Ejecutar

Para ejecutar la aplicación en Windows:

```bash
flutter run -d windows
```

O para compilar una versión de producción:

```bash
flutter build windows
```

El ejecutable estará en: `build/windows/runner/Release/mai_ai.exe`

## 🎤 Cómo Usar el Modo Voz

### Activar Modo Voz

Hay dos formas de activar el modo voz:

1. **Con el botón del AppBar**
   - Haz clic en el icono del micrófono en la esquina superior derecha

2. **Con atajo de teclado**
   - Presiona `Ctrl + M`

### Flujo de Uso

1. **Activar modo voz**
   - Mai te dará la bienvenida: "Modo de voz activado. Dime qué necesitas."
   - Verás un banner morado indicando "Modo voz activo"

2. **Presionar para hablar**
   - Haz clic en el botón "Presiona para hablar"
   - El banner cambiará a "Escuchando..." (color morado)
   - Habla claramente tu pregunta o mensaje

3. **Esperar la respuesta**
   - Mai procesará tu mensaje automáticamente
   - Verás el texto reconocido en el chat
   - Mai responderá con texto Y con voz
   - El banner mostrará "Mai está hablando..." (color azul)

4. **Continuar la conversación**
   - Cuando Mai termine de hablar, automáticamente volverá a estar lista para escuchar
   - Presiona nuevamente "Presiona para hablar" para continuar

5. **Detener la voz de Mai** (opcional)
   - Si Mai está hablando y quieres interrumpirla, haz clic en "Detener voz"

6. **Desactivar modo voz**
   - Haz clic nuevamente en el icono del micrófono o presiona `Ctrl + M`
   - Volverás al modo de texto normal

### Indicadores Visuales

- **🎤 Icono de micrófono en el título**: Modo voz está activo
- **Banner morado "Escuchando..."**: Mai está escuchando tu voz
- **Banner azul "Mai está hablando..."**: Mai está respondiendo con voz
- **Banner gris "Modo voz activo"**: Modo voz activo pero sin actividad
- **Botón rojo "Detener"**: Puedes detener la escucha
- **Botón morado "Presiona para hablar"**: Listo para escuchar

## 🔧 Solución de Problemas

### El micrófono no funciona

**Problema**: Mai no reconoce tu voz

**Soluciones**:
1. Verifica que el micrófono esté conectado y funcionando
2. Comprueba los permisos de micrófono en Windows (Ver sección Prerequisitos)
3. Prueba el micrófono en otra aplicación (ej: Grabadora de voz)
4. Reinicia la aplicación Mai
5. Revisa los logs en la consola para ver mensajes de error

### No hay voces en español

**Problema**: Mai habla en inglés o no habla

**Soluciones**:
1. Verifica que tengas voces en español instaladas (Ver sección "Instalar Voces en Español")
2. Ve a Configuración de Windows → Hora e idioma → Voz
3. Selecciona una voz en español como predeterminada
4. Reinicia la aplicación Mai

### El reconocimiento es impreciso

**Problema**: Mai no entiende lo que dices o reconoce mal las palabras

**Soluciones**:
1. Habla más claramente y despacio
2. Reduce el ruido de fondo
3. Ajusta el volumen del micrófono en Windows
4. Acércate más al micrófono
5. Entrena el reconocimiento de voz de Windows:
   - Ve a Configuración → Hora e idioma → Voz
   - Haz clic en "Mejorar el reconocimiento de voz"

### Error "Servicio de voz no disponible"

**Problema**: Aparece un mensaje de error al activar el modo voz

**Soluciones**:
1. Verifica que las dependencias estén instaladas: `flutter pub get`
2. Comprueba los logs en la consola para más detalles
3. Reinicia la aplicación
4. Verifica que no haya otras aplicaciones usando el micrófono

### La aplicación se congela

**Problema**: La UI se congela al usar el modo voz

**Soluciones**:
1. Verifica tu conexión a Internet (necesaria para la API de IA)
2. Revisa los logs de la consola para errores
3. Intenta desactivar y reactivar el modo voz
4. Reinicia la aplicación

### Errores de compilación

**Problema**: Errores al ejecutar `flutter run -d windows`

**Soluciones**:
1. Ejecuta `flutter clean` y luego `flutter pub get`
2. Verifica que tengas las herramientas de desarrollo de Windows instaladas
3. Ejecuta `flutter doctor` y soluciona cualquier problema
4. Actualiza Flutter a la última versión: `flutter upgrade`

## ⌨️ Atajos de Teclado

| Atajo | Acción |
|-------|--------|
| `Ctrl + M` | Activar/Desactivar modo voz |

## 📝 Notas Técnicas

### Configuración de Voz

La aplicación está configurada con los siguientes parámetros:

**Speech-to-Text (STT)**:
- Idioma: Español (es-ES o es-MX)
- Modo de escucha: Confirmación
- Tiempo máximo de escucha: 30 segundos
- Pausa de silencio: 3 segundos
- Resultados parciales: Activados

**Text-to-Speech (TTS)**:
- Idioma: Español (es-ES)
- Velocidad de habla: 0.5 (50%)
- Volumen: 1.0 (100%)
- Tono: 1.0 (normal)

### Logs de Depuración

La aplicación genera logs informativos en la consola. Para verlos:

1. Ejecuta la app desde la terminal: `flutter run -d windows`
2. Observa los mensajes con emojis:
   - 🎤 Eventos de micrófono
   - 🗣️ Eventos de voz
   - ✅ Operaciones exitosas
   - ❌ Errores
   - 📊 Cambios de estado
   - 🎯 Resultados de reconocimiento

### Rendimiento

Para mejor rendimiento:
- Cierra otras aplicaciones que usen el micrófono
- Asegúrate de tener una buena conexión a Internet
- Usa un micrófono de calidad
- Mantén el volumen del micrófono en un nivel apropiado

## 🔒 Privacidad

- El reconocimiento de voz se procesa localmente en tu dispositivo usando las APIs de Windows
- Los mensajes de texto se envían a la API de OpenRouter para obtener respuestas de IA
- No se graban ni almacenan archivos de audio
- Las conversaciones se guardan localmente usando SharedPreferences

## 🆘 Obtener Ayuda

Si encuentras problemas:

1. Revisa esta guía de solución de problemas
2. Verifica los logs en la consola
3. Asegúrate de tener la configuración correcta de Windows
4. Crea un issue en el repositorio del proyecto

## 📚 Recursos Adicionales

- [Documentación de Flutter Windows](https://docs.flutter.dev/desktop#windows)
- [speech_to_text package](https://pub.dev/packages/speech_to_text)
- [flutter_tts package](https://pub.dev/packages/flutter_tts)
- [Configuración de Voz en Windows](https://support.microsoft.com/es-es/windows/uso-del-reconocimiento-de-voz-en-windows-83ff75bd-63eb-0b6c-18d4-6fae94050571)

---

**¡Disfruta conversando con Mai! 🎉**
