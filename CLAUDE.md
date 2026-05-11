# PartsFlow Mobile — Guía de Trabajo

## Regla principal (CRÍTICA)

**NO ESCRIBAS CÓDIGO Y NO ME MUESTRES CÓDIGO A MENOS QUE YO LO PIDA EXPLÍCITAMENTE.**

El propósito de este proyecto es que **yo aprenda a trabajar con Dart y Flutter**. Tu rol es el de un tutor/mentor, no el de un generador de código.

### Cómo responder a mis preguntas

- Explicá **conceptos**, **flujos**, **decisiones de arquitectura** y **cuándo usar qué**.
- Usá diagramas en ASCII, tablas, listas, y descripciones en prosa.
- Mostrá la **estructura de carpetas**, **nombres de archivos**, **responsabilidades de cada capa**.
- Si necesitás referenciar un concepto técnico, describilo con palabras (ej: "el método `fromJson` recibe un Map y devuelve la entidad").
- Si una pregunta solo se puede responder con código, **primero preguntame** si quiero ver el código o solo la explicación conceptual.

### Cuándo SÍ puedo querer código

Solo cuando yo diga explícitamente cosas como:
- "Mostrame el código de..."
- "Escribí esto..."
- "Implementá..."
- "Dame un ejemplo de código..."
- "¿Cómo se ve en código?"

Si tengo dudas, **preguntame antes de escribir**.

### Qué SÍ podés hacer sin pedírtelo

- Ejecutar comandos de terminal (instalar paquetes, correr build_runner, etc.)
- Crear/modificar archivos de **configuración** (pubspec.yaml, analysis_options.yaml, settings)
- Leer archivos para entender el estado del proyecto
- Explicar errores que me aparezcan
- Sugerir nombres de archivos y carpetas

---

## Sobre mí (el usuario)

- Email: franco.carrasco@repartes.com
- Estoy construyendo **PartsFlow Mobile**, una app Flutter mediana-grande.
- Soy olvidadizo, así que este archivo me sirve para retomar contexto.
- Quiero **entender** lo que hago, no copiar/pegar.

---

## Arquitectura: Feature-First + Hexagonal (Clean Architecture)

### Principio fundamental

Las dependencias apuntan hacia el dominio:

```
Presentation  →  Domain  ←  Data
```

- **Domain** no conoce a nadie (Dart puro, sin Flutter, sin Dio, sin Drift).
- **Data** y **Presentation** dependen de **Domain**.
- **Data** y **Presentation** **no se conocen entre sí**.

### Estructura de carpetas

```
lib/
├── main.dart
├── app.dart                      # MaterialApp, theme, router
│
├── core/                         # Infraestructura compartida (2+ features)
│   ├── network/                  # Dio, interceptores, WebSocket
│   ├── storage/                  # Wrappers de secure_storage y shared_preferences
│   ├── errors/                   # Failures, Exceptions
│   ├── router/                   # GoRouter config y guards
│   ├── theme/                    # Colores, tipografía
│   ├── utils/                    # Result<T>, extensiones
│   └── providers/                # Providers globales (Dio, storages)
│
├── features/
│   └── <feature>/
│       ├── data/
│       │   ├── datasources/      # Remote (Retrofit) y Local (Drift/storage)
│       │   ├── models/           # DTOs con fromJson/toJson
│       │   └── repositories/     # Implementaciones
│       ├── domain/
│       │   ├── entities/         # Modelos del negocio (Dart puro)
│       │   ├── repositories/     # Interfaces abstractas
│       │   └── usecases/         # Acciones del negocio
│       └── presentation/
│           ├── providers/        # Notifiers de Riverpod
│           ├── pages/            # Pantallas
│           └── widgets/          # Widgets de la feature
│
└── shared/                       # Widgets reutilizables cross-feature
    ├── widgets/                  # LoadingIndicator, ErrorView, EmptyState
    └── extensions/
```

### Responsabilidades por capa

| Capa | Conoce | NO conoce | Responsabilidad |
|---|---|---|---|
| **domain/** | Dart puro | Flutter, Dio, Drift, JSON | Reglas y conceptos del negocio |
| **data/** | Librerías externas, JSON, DB | Flutter widgets | Cómo obtener/guardar los datos |
| **presentation/** | Flutter, Riverpod, domain | data/ | Mostrar UI y manejar estado |

### Reglas para crear features

Una feature nueva se crea cuando:
- Tiene sus propias pantallas
- Tiene sus propios endpoints/recursos
- Podría existir aislada de las demás

Features previstas: `auth`, `orders`, `catalog`, `chat`, `notifications`, `profile`, `cart`.

---

## Stack de dependencias instaladas

### Runtime

| Paquete | Para qué |
|---|---|
| `flutter_riverpod` ^3.3.1 | State management (global y por feature) |
| `riverpod_annotation` ^4.0.2 | Anotaciones para generar providers |
| `dio` ^5.9.2 | Cliente HTTP base |
| `retrofit` ^4.9.2 | Generador de API REST sobre Dio |
| `flutter_secure_storage` ^10.1.0 | Tokens y datos sensibles (cifrado por SO) |
| `shared_preferences` ^2.5.5 | Preferencias y flags no sensibles |
| `freezed_annotation` ^3.1.0 | Anotaciones para modelos inmutables |
| `json_annotation` ^4.11.0 | Anotaciones para serialización JSON |

### Dev (codegen)

| Paquete | Para qué |
|---|---|
| `build_runner` ^2.15.0 | Motor de generación de código |
| `riverpod_generator` ^4.0.3 | Genera providers desde anotaciones |
| `freezed` ^3.2.5 | Genera clases inmutables, copyWith, unions |
| `json_serializable` ^6.13.0 | Genera fromJson/toJson |
| `retrofit_generator` ^10.2.6 | Genera cliente HTTP desde la interfaz |

### Pendientes de decidir / instalar

- **Routing**: `go_router` (cuando empecemos navegación)
- **Caché estructurado**: `drift` o `isar` (cuando haya datos relacionales para offline)
- **WebSocket**: `web_socket_channel` o `socket_io_client` (cuando el backend lo defina)
- **Lint adicional**: `riverpod_lint` está bloqueado por conflicto con `flutter_riverpod 3.3.1`

---

## Qué librería usar para cada cosa

| Necesidad | Librería |
|---|---|
| Estado de UI / app | `flutter_riverpod` |
| Petición HTTP REST | `dio` + `retrofit` |
| Token JWT, refresh token, credenciales | `flutter_secure_storage` |
| Tema, idioma, flags, último filtro | `shared_preferences` |
| Modelo inmutable con copyWith | `freezed` |
| Parseo JSON ↔ Dart | `json_serializable` (combinado con freezed para DTOs) |
| Estado tipo "loading/data/error" | `freezed` con `sealed` + union types |
| Errores explícitos en repos | `Result<T>` propio (sealed class en `core/utils/`) |

### Reglas de uso del storage

- **`flutter_secure_storage`** → `access_token`, `refresh_token`, credenciales, PIN, cualquier cosa cuya filtración comprometa la cuenta.
- **`shared_preferences`** → tema, idioma, "vio el onboarding", filtros guardados, perfil del usuario (como JSON).
- **DB estructurada (Drift/Isar)** → caché offline de listados, datos relacionales.

---

## Comandos importantes

### Generar código (freezed, json, retrofit, riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Modo watch (regenera al guardar)

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Instalar nuevas dependencias

```bash
flutter pub add <paquete>            # runtime
flutter pub add dev:<paquete>        # dev
```

### Correr la app

```bash
flutter run
```

---

## Glosario rápido (para no olvidarme)

- **DTO (Data Transfer Object)**: clase que representa lo que viene del backend. Vive en `data/models/`. Tiene `fromJson`/`toJson`.
- **Entity**: clase del dominio, limpia, sin JSON. Vive en `domain/entities/`.
- **Repository (interfaz)**: contrato de operaciones. Vive en `domain/repositories/`.
- **Repository (impl)**: implementación real. Vive en `data/repositories/`. Decide caché vs red.
- **UseCase**: una acción del negocio (ej: `GetOrdersUseCase`). Vive en `domain/usecases/`.
- **DataSource**: capa que habla directamente con la fuente (API o DB). Vive en `data/datasources/`.
- **Provider (Riverpod)**: expone un valor o estado a la UI. Vive en `presentation/providers/`.
- **Failure**: representación de un error en el dominio. Vive en `core/errors/`.
- **Interceptor**: middleware de Dio que se ejecuta antes/después de cada request.

---

## Flujos clave de la app

### Flujo de petición HTTP autenticada

1. UseCase pide datos al repositorio
2. Repository llama al datasource (Retrofit)
3. Retrofit usa Dio internamente
4. AuthInterceptor agrega el token
5. Si responde 401 → interceptor refresca token y reintenta
6. Response → DTO → Entity → vuelve al UseCase

### Flujo de login

1. LoginPage → provider → LoginUseCase
2. UseCase llama a AuthRepository
3. Repository pide a la API (Retrofit)
4. Guarda tokens en `flutter_secure_storage`
5. Guarda perfil en `shared_preferences`
6. Conecta WebSocket con el token
7. Provider actualiza estado → router redirige

### Flujo de lectura con caché

1. UseCase pide datos al repositorio
2. Repository intenta llamada remota
3. Si éxito → cachea localmente + devuelve
4. Si falla → devuelve caché local (si existe)
5. Si no hay caché → devuelve Failure

---

## Recordatorios para Claude

- No escribas código sin que yo lo pida.
- No me muestres archivos `.dart` generados ni de ejemplo a menos que yo lo pida.
- Si te pregunto "cómo funciona X" → explicación conceptual, no código.
- Si te pregunto "cómo implemento X" → explicación de pasos, flujo, dónde van las cosas. Si necesito código, te lo pediré.
- Si te pregunto "mostrame cómo" → ahí sí podés mostrar código.
- Cuando ejecutes `build_runner`, avisame qué archivos se generaron y dónde.
- Si ves que estoy a punto de romper la regla de dependencias (ej: importar Dio en `domain/`), avisame.
