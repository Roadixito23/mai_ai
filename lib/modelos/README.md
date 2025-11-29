# Modelos de Datos - Mai AI

Esta carpeta contiene todos los modelos de datos utilizados en la aplicación Mai AI.

## 📚 Lista de Modelos

### 1. **ChatMessage** (`chat_message.dart`)
Representa un mensaje individual en el chat.

**Campos principales:**
- `id`: Identificador único del mensaje
- `text`: Contenido del mensaje
- `isUser`: Indica si el mensaje es del usuario o de la IA
- `timestamp`: Momento en que se creó el mensaje
- `modelId`: Modelo de IA usado (si es respuesta de IA)
- `isError`: Indica si el mensaje es un error
- `metadata`: Datos adicionales opcionales
- `tokensUsed`: Número de tokens utilizados

**Constructores factory:**
- `ChatMessage.user()`: Crear mensaje del usuario
- `ChatMessage.assistant()`: Crear mensaje de la IA
- `ChatMessage.error()`: Crear mensaje de error

**Ejemplo:**
```dart
final userMsg = ChatMessage.user(text: 'Hola Mai');
final aiMsg = ChatMessage.assistant(
  text: 'Hola! ¿Cómo puedo ayudarte?',
  modelId: 'gemini-2.5-flash',
);
```

---

### 2. **Conversation** (`conversation.dart`)
Representa una conversación completa con Mai.

**Campos principales:**
- `id`: Identificador único de la conversación
- `title`: Título de la conversación
- `messages`: Lista de mensajes
- `createdAt`: Fecha de creación
- `updatedAt`: Fecha de última actualización
- `modelId`: Modelo de IA usado en la conversación
- `isPinned`: Indica si la conversación está fijada

**Métodos útiles:**
- `addMessage()`: Agregar un mensaje a la conversación
- `messageCount`: Obtener el número total de mensajes
- `lastMessage`: Obtener el último mensaje
- `isEmpty`: Verificar si está vacía

**Ejemplo:**
```dart
final conversation = Conversation.create(
  title: 'Mi primera conversación',
  modelId: 'gemini-2.5-flash',
);

final updated = conversation.addMessage(
  ChatMessage.user(text: 'Hola'),
);
```

---

### 3. **AIModel** (`ai_model.dart`)
Representa un modelo de IA disponible.

**Campos principales:**
- `id`: Identificador del modelo (ej: 'gemini-2.5-flash')
- `name`: Nombre amigable del modelo
- `description`: Descripción del modelo
- `isFree`: Indica si el modelo es gratuito
- `provider`: Proveedor del modelo (ej: 'Google')

**Métodos estáticos:**
- `availableModels`: Lista de todos los modelos disponibles
- `freeModels`: Lista de modelos gratuitos
- `paidModels`: Lista de modelos de pago
- `findById()`: Buscar modelo por ID

**Ejemplo:**
```dart
final model = AIModel.findById('gemini-2.5-flash');
final freeModels = AIModel.freeModels;
```

---

### 4. **AIResponse** (`ai_response.dart`)
Representa una respuesta estructurada de la IA.

**Campos principales:**
- `text`: Texto de la respuesta
- `modelId`: Modelo usado para generar la respuesta
- `timestamp`: Momento de la respuesta
- `tokensUsed`: Tokens utilizados
- `responseTimeMs`: Tiempo de respuesta en milisegundos
- `metadata`: Metadatos adicionales
- `isError`: Indica si es un error
- `errorMessage`: Mensaje de error (si aplica)

**Constructores factory:**
- `AIResponse.success()`: Crear respuesta exitosa
- `AIResponse.error()`: Crear respuesta de error

**Propiedades calculadas:**
- `isSuccess`: Verifica si la respuesta fue exitosa
- `displayText`: Obtiene el texto a mostrar
- `tokensPerSecond`: Calcula tokens por segundo

**Ejemplo:**
```dart
final response = AIResponse.success(
  text: 'Respuesta de Mai',
  modelId: 'gemini-2.5-flash',
  tokensUsed: 150,
  responseTimeMs: 1500,
);

print('Tokens/seg: ${response.tokensPerSecond}');
```

---

### 5. **UserPreferences** (`user_preferences.dart`)
Representa las preferencias del usuario.

**Campos principales:**
- `preferredModelId`: Modelo de IA preferido
- `theme`: Tema de la aplicación ('light', 'dark', 'system')
- `voiceModeEnabled`: Modo de voz activado
- `language`: Idioma preferido
- `streamingEnabled`: Streaming de respuestas activado
- `showTimestamps`: Mostrar marcas de tiempo
- `soundEnabled`: Sonidos activados
- `fontSize`: Tamaño de fuente
- `autoScrollEnabled`: Auto-scroll activado

**Constructores factory:**
- `UserPreferences.defaults()`: Crear con valores predeterminados

**Ejemplo:**
```dart
final prefs = UserPreferences.defaults();
final updated = prefs.copyWith(
  preferredModelId: 'gemini-2.5-pro',
  theme: 'dark',
);
```

---

### 6. **VoiceSettings** (`voice_settings.dart`)
Representa la configuración de voz (STT y TTS).

**Campos STT (Speech-to-Text):**
- `sttLanguage`: Idioma para reconocimiento de voz
- `maxListeningSeconds`: Tiempo máximo de escucha
- `pauseSilenceSeconds`: Pausa de silencio antes de detener
- `partialResults`: Mostrar resultados parciales
- `onDeviceRecognition`: Usar reconocimiento local

**Campos TTS (Text-to-Speech):**
- `ttsLanguage`: Idioma para síntesis de voz
- `speechRate`: Velocidad de habla (0.0 - 1.0)
- `volume`: Volumen (0.0 - 1.0)
- `pitch`: Tono (0.5 - 2.0)
- `preferredVoice`: Voz preferida

**Constructores factory:**
- `VoiceSettings.defaults()`: Configuración predeterminada
- `VoiceSettings.spanishSpain()`: Optimizada para español de España
- `VoiceSettings.spanishMexico()`: Optimizada para español de México

**Ejemplo:**
```dart
final settings = VoiceSettings.spanishMexico();
final custom = settings.copyWith(
  speechRate: 0.7,
  volume: 0.8,
);

if (custom.isValid) {
  // Aplicar configuración
}
```

---

## 🔄 Migración de Modelos Existentes

### ChatMessage
Se actualizó el modelo `ChatMessage` con los siguientes campos nuevos:
- `id`: Para identificación única
- `modelId`: Para rastrear qué modelo generó la respuesta
- `isError`: Para manejar errores
- `metadata`: Para datos adicionales
- `tokensUsed`: Para métricas de uso

**Nota de compatibilidad:** El modelo sigue siendo compatible con versiones anteriores gracias a parámetros opcionales y valores por defecto.

---

## 📦 Importación

Puedes importar todos los modelos desde un único archivo:

```dart
import 'package:mai_ai/modelos/modelos.dart';
```

O importar modelos individuales:

```dart
import 'package:mai_ai/modelos/chat_message.dart';
import 'package:mai_ai/modelos/conversation.dart';
```

---

## 🧪 Serialización

Todos los modelos incluyen:
- Método `toJson()`: Para convertir a JSON
- Constructor `fromJson()`: Para crear desde JSON
- Implementación de `==` y `hashCode` para comparaciones
- Método `toString()` para debugging (algunos modelos)

**Ejemplo de uso:**
```dart
// Serializar
final message = ChatMessage.user(text: 'Hola');
final json = message.toJson();

// Deserializar
final restored = ChatMessage.fromJson(json);

// Guardar en SharedPreferences
final prefs = await SharedPreferences.getInstance();
await prefs.setString('message', jsonEncode(json));
```

---

## 🎯 Buenas Prácticas

1. **Usa constructores factory** cuando sea apropiado para crear instancias con valores semánticos
2. **Usa `copyWith()`** para crear copias modificadas de objetos inmutables
3. **Valida datos** antes de crear instancias (ej: `VoiceSettings.isValid`)
4. **Maneja errores** usando los constructores `.error()` cuando estén disponibles
5. **Serializa correctamente** usando los métodos `toJson()` y `fromJson()`

---

## 📝 Contribuir

Al agregar nuevos modelos:
1. Crea el archivo en `lib/modelos/`
2. Implementa `toJson()` y `fromJson()`
3. Implementa `==` y `hashCode` si es necesario
4. Agrega el export en `modelos.dart`
5. Documenta el modelo en este README
6. Considera agregar constructores factory para casos de uso comunes

---

**Última actualización:** 2025-11-29
