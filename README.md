# gestor_cafeteria

Cliente Flutter de una cafetería que consume la API de pedidos **mini_backend**. Incluye un cliente HTTP (`ApiClient`) que traduce cada respuesta del servidor a un `Failure` tipado (no encontrado, conflicto, validación, error del servidor, sin conexión o inesperado) y pruebas automatizadas que lo verifican sin depender del servidor real.

## Requisitos

- Flutter 3.x estable con Dart 3.x (probado con Flutter 3.47.2 y Dart 3.13.2).
- Node.js **22.13 o superior** (para ejecutar mini_backend). Compruébalo con `node --version`.
- Un emulador de Android, Chrome o un celular.

## Servidor: mini_backend

mini_backend es **otro repositorio** y no se incluye en este proyecto:

- Repositorio: <https://github.com/DMI-2026/mini_backend> (rama `master`)
- Versión con la que se probó: commit `94d2533` (2026-10-08)

Para levantarlo:

```bash
git clone https://github.com/DMI-2026/mini_backend.git
cd mini_backend
node server.js          # no hace falta npm install
```

Debe mostrar `Listening on http://0.0.0.0:8000`. Comprueba en el navegador <http://localhost:8000/health>; debe responder `{"status":"ok"}`.

## Ejecutar la app

```bash
flutter pub get
flutter run                     # emulador de Android: usa http://10.0.2.2:8000
flutter run -d chrome           # Chrome: usa http://localhost:8000
```

En un celular físico indica la IP de tu computadora con `API_URL` (ambos en la misma red):

```bash
flutter run --dart-define=API_URL=http://<IP de tu computadora>:8000
```

## Pruebas

```bash
flutter analyze   # debe terminar sin errores ni advertencias
flutter test      # pruebas de Failure y del ApiClient con MockClient
```

Las pruebas de `test/core/http_client_test.dart` usan `MockClient` (`package:http/testing.dart`), así que **no** necesitan el servidor ni red.

## Estructura de carpetas

```text
lib/
  core/
    failure.dart        # sealed class Failure y sus subtipos
    http_client.dart    # ApiClient: GET/POST/PATCH/DELETE y mapeo HTTP -> Failure
  main.dart             # pantalla de prueba que lista los pedidos
test/
  core/
    failure_test.dart       # pruebas de la jerarquía de fallos
    http_client_test.dart   # pruebas del ApiClient con MockClient
```

## Mapeo de errores

| Respuesta | Failure |
|---|---|
| 404 | `NotFoundFailure` (mensaje de `detail`) |
| 409 | `ConflictFailure` (mensaje de `detail`) |
| 422 | `ValidationFailure` (`fields`: `loc[1]` → `msg`) |
| 500–599 | `ServerFailure` (código de estado) |
| Otra respuesta no exitosa (incluye 3xx) | `UnexpectedFailure` (código y mensaje) |
| Sin conexión o tiempo agotado | `NetworkFailure` |
