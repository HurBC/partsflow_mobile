# Versionado de PartsFlow Mobile

La versión vive en `pubspec.yaml` con el formato `X.Y.Z+N` (por ejemplo, `version: 1.8.0+10`).

## X.Y.Z

| Parte | Cuándo sube | Ejemplos |
|---|---|---|
| **X** (módulo) | Un **módulo nuevo**: una sección nueva con pantallas propias en `lib/features/`. También un cambio que rompe algo para el usuario: rediseño completo de un módulo, forzar un nuevo login, dejar de soportar una versión de Android. | Catálogo, notificaciones |
| **Y** (funcionalidad) | Una **funcionalidad nueva dentro de un módulo existente**. | Acciones desde el listado de chats, tarjetas de acción requerida, recordatorios |
| **Z** (parche) | **Fixes y ajustes** sin funcionalidad nueva: bugs, rendimiento, textos, estilos. | Quitar un espacio vacío en el listado, corregir un crash |

### Reglas

1. **Manda la categoría más alta del release.** Una funcionalidad junto con varios fixes sube **Y**, no Y+Z.
2. **Al subir una parte, se reinicia lo de abajo.**
   - Fix: `1.8.0` → `1.8.1`
   - Funcionalidad: `1.8.3` → `1.9.0`
   - Módulo nuevo: `1.9.0` → `2.0.0`
3. **Se sube una vez por PR a `main`, no en cada commit.** Se hace en el último commit del PR, así no se saltan números ni hay conflictos en `pubspec.yaml`.

## Build number (+N)

- Es el `versionCode` de Android y **siempre sube**, sin importar X.Y.Z. Android no instala un APK con un número menor que el instalado sin desinstalarlo antes, y eso borra la sesión y los datos de la app.
- Se suma **+1 en cada APK que se distribuye**: release, prueba en teléfono o GitHub Release.

## Tags y releases

- Al mergear a `main`, opcionalmente se crea el tag `vX.Y.Z` sobre el commit del merge.
- `scripts/release-apk.sh` publica los APK como GitHub Release con esa versión.

## Punto de partida

Este esquema rige desde **1.8.0+10**. Las versiones anteriores no lo seguían.
