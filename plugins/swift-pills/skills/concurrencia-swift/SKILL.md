---
name: concurrencia-swift
description: "Swift Concurrency en Swift 6, 6.2 y 6.4. Cubre aislamiento con @MainActor y actores, Approachable Concurrency (nonisolated(nonsending), @concurrent, Default Actor Isolation), Sendable y @Sendable, sending, conformidades aisladas (@MainActor Equatable), protocolos con @MainActor, continuaciones (CheckedContinuation, UnsafeContinuation y Continuation no copiable), cancelación y withTaskCancellationShield, Mutex de Synchronization frente a actores, GCD y OSAllocatedUnfairLock, carga progresiva con AsyncSequence, NotificationCenter tipado (MainActorMessage, AsyncMessage) y migración a Swift 6. Úsala al escribir o revisar código async/await, al resolver diagnósticos como \"sending value of non-Sendable type\" o \"conformance crosses into main actor-isolated code\" y al decidir dónde vive el estado compartido."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/conformar-protocolos-en-swift-6-navegando-por-los-desafios-de-aislamiento-de-actores/
    - https://www.swiftpills.dev/posts/thread-safety-en-swift-gcd-con-barreras-osallocatedunfairlock-o-actors/
    - https://www.swiftpills.dev/posts/notificationcenter-en-swift-6-2-sigues-usando-el-metodo-antiguo-con-warnings-de-concurrencia/
    - https://www.swiftpills.dev/posts/swift-6-te-parece-complicado-las-herramientas-de-migracion-automatica-lo-cambiaran-todo/
    - https://www.swiftpills.dev/posts/swift-6-2-cambia-las-reglas-del-juego-en-concurrencia-sera-finalmente-sencillo-para-todos/
    - https://www.swiftpills.dev/posts/mutex-en-swift-estado-mutable-compartido/
    - https://www.swiftpills.dev/posts/task-cancellation-shields-swift-6-4/
    - https://www.swiftpills.dev/posts/sendable-en-swift-datos-seguros-entre-dominios-de-aislamiento/
    - https://www.swiftpills.dev/posts/protocolos-mainactor-swift/
    - https://www.swiftpills.dev/posts/continuation-checkedcontinuation-unsafecontinuation-swift/
    - https://www.swiftpills.dev/posts/sendable-y-sendable-en-swift/
    - https://www.swiftpills.dev/posts/approachable-concurrency-swift-6-2/
    - https://www.swiftpills.dev/posts/carga-iterativa-datos-swift/
    - https://www.swiftpills.dev/posts/arquitectura-swiftui-concurrencia-estado-aislamiento/
  actualizada: 2026-11-25
---

# Concurrencia en Swift

Razona en actores, dominios de aislamiento y executors, no en hilos. `await` marca un punto de suspensión, no un cambio de hilo. Para comprobar aislamiento usa `MainActor.assertIsolated()`, no `Thread.isMainThread`.

## Arquitectura: un propietario para cada estado

1. **Estado de interfaz** en un modelo `@MainActor @Observable`. `@Observable` no implica `@MainActor`: decláralo explícitamente.
2. **Estado compartido que no es de interfaz** (cachés, sesiones, operaciones pendientes) en un `actor`.
3. **Trabajo sin estado** en `struct` o servicios `Sendable` que reciben y devuelven valores `Sendable`. Marca con `@concurrent` el trabajo pesado de CPU.

```swift
@MainActor @Observable
final class SkyAgenda {
    private(set) var events: [SkyEvent] = []
    private(set) var isLoading = false
    private let source: any SkyEventSource

    init(source: any SkyEventSource) { self.source = source }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do { events = try await source.load() }
        catch is CancellationError { return }
        catch { /* mostrar error */ }
    }
}

nonisolated protocol SkyEventSource: Sendable {
    func load() async throws -> [SkyEvent]
}

nonisolated struct JSONSkyEventSource: SkyEventSource {
    let data: Data
    @concurrent func load() async throws -> [SkyEvent] {
        try JSONDecoder().decode([SkyEvent].self, from: data)
    }
}
```

No añadas atributos hasta que compile. Da a cada estado un propietario y a cada operación un contexto de ejecución claro.

## Swift 6.2: Approachable Concurrency

Con `NonisolatedNonsendingByDefault` (SE-0461), activado en los proyectos nuevos de Xcode 26:

| Declaración | Dónde se ejecuta |
|---|---|
| `@MainActor func f() async` | En `MainActor` |
| `nonisolated func f() async` | En el actor del llamador |
| `nonisolated(nonsending) func f() async` | En el actor del llamador, aunque el ajuste esté desactivado |
| `@concurrent func f() async` | Fuera del actor del llamador, en el executor genérico; argumentos y resultado deben ser `Sendable` o transferibles |

- `@concurrent` ya implica `nonisolated`.
- Usa `@concurrent` solo para trabajo síncrono intensivo dentro de una función `async`: decodificar, hacer hashes, procesar miles de registros. No hace falta para peticiones de red, que pasan el tiempo suspendidas. No es un sustituto de `DispatchQueue.global().async`.
- **Default Actor Isolation** (SE-0466) es un ajuste independiente: infiere `@MainActor` en las declaraciones sin anotar. En SwiftPM se activa con `.defaultIsolation(MainActor.self)` en `swiftSettings`. Con él activo, marca como `nonisolated` los modelos, servicios y utilidades que no deban vivir en el actor principal.
- Approachable Concurrency incluye `DisableOutwardActorInference`, `GlobalActorIsolatedTypesUsability`, `InferIsolatedConformances`, `InferSendableFromCaptures` y `NonisolatedNonsendingByDefault`. En proyectos existentes, activa las características de una en una con las herramientas de migración: el comportamiento cambia, porque hay código que antes salía del actor y ahora se queda en él.

## Sendable

- `Sendable` describe valores y `@Sendable` describe funciones y closures que pueden cruzar dominios.
- `struct` y `enum` son `Sendable` si todas sus propiedades o valores asociados lo son. Declara la conformidad explícitamente cuando forme parte del contrato, sobre todo en tipos públicos: si alguien añade una propiedad no `Sendable`, el error aparece en la definición.
- Una clase `Sendable` comprobada debe ser `final`, con propiedades `let` que también sean `Sendable`.
- Los actores son `Sendable` implícitamente.
- Exige `@Sendable` en un parámetro solo si la API va a compartir el closure entre dominios. Para capturar una instantánea, usa una lista de captura: `{ [threshold] item in ... }`.
- Los genéricos que envían valores a otro contexto deben exigir `Value: Sendable`.
- `sending` transfiere una instancia no `Sendable` concreta. El llamador no puede volver a usarla después.
- `@unchecked Sendable` desactiva la comprobación y deja la prueba en tus manos. Resérvalo para código heredado auditado. En código nuevo usa `Mutex` o un actor.
- `@preconcurrency import` reduce los diagnósticos de frameworks antiguos durante una migración, pero no los hace seguros.

**Ante un diagnóstico de envío,** localiza la frontera (llamada a un actor, `Task`, parámetro `@Sendable`) y el estado mutable que quedaría visible desde ambos lados. Según el caso:

- Datos independientes: `struct` de valores `Sendable`.
- Referencia inmutable: clase `final` con propiedades `let`.
- Estado mutable compartido: un `actor`.
- Cambio de propietario: `sending`.
- Sincronización manual: `Mutex` antes que `@unchecked Sendable`.

`Sendable` evita carreras de datos, no condiciones de carrera lógicas. Varias llamadas a un actor no forman una operación atómica, y un actor admite reentrada en cada `await`.

## Protocolos y aislamiento

| Declaración | Significado |
|---|---|
| `@MainActor protocol P` | Todo el protocolo pertenece a `MainActor`. Conformar en la declaración principal propaga `@MainActor` al tipo entero |
| `protocol P { @MainActor func f() }` | Solo `f()` está aislado; un `actor` puede conformar |
| `Type: @MainActor P` | Conformidad aislada (SE-0470, Swift 6.2): un protocolo no aislado como `Equatable`, usado solo desde `MainActor` |
| `nonisolated Type: P` | Corta la inferencia de actor global que llegaría por la conformidad |

- Un `actor` no puede adoptar un protocolo `@MainActor` entero. Aísla solo los requisitos de presentación.
- Conformar en una extensión limita el aislamiento a los requisitos; el resto del tipo sigue sin aislar.
- Si un requisito depende del estado de un actor, decláralo `async`: un requisito síncrono no aislado no se puede satisfacer desde un actor.
- Cuando un tipo `@MainActor` necesita `Equatable`, `Codable` o similares, prefiere `extension Model: @MainActor Equatable` a `@preconcurrency` o a `nonisolated` con `MainActor.assumeIsolated`.

## Continuaciones

Para adaptar APIs con completion handlers o delegates, reanuda exactamente una vez en cada camino. Pon `return` después de cada `resume`.

| | `CheckedContinuation` | `UnsafeContinuation` | `Continuation` (Swift 6.4, SE-0528) |
|---|---|---|---|
| Doble `resume` | Trap en ejecución | Comportamiento indefinido | Error de compilación sobre el mismo valor |
| Sin `resume` | Aviso en ejecución | La tarea queda suspendida sin aviso | Trap en `deinit` |
| Copiable | Sí | Sí | No (`~Copyable`, `resume` es `consuming`) |
| Úsala para | Código de app y callbacks separados de éxito y error | Infraestructura medida y controlada | Un único propietario que centraliza la finalización |

```swift
extension LegacyAccessCodeService {
    func requestCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            requestCode { result in continuation.resume(with: result) }
        }
    }
}

// Swift 6.4: errores tipados y propietario único
let url = try await withContinuation(of: URL.self, throwing: ImportError.self) { continuation in
    coordinator.continuation = consume continuation
}
```

- Las continuaciones no propagan la cancelación. Usa `withTaskCancellationHandler` y resuelve la carrera entre resultado y cancelación con un actor o un estado protegido.
- Para eventos repetidos usa `AsyncStream` o `AsyncThrowingStream`, nunca varios `resume`.

## Cancelación

- La cancelación es cooperativa: comprueba `Task.checkCancellation()` o `Task.isCancelled` entre etapas. Trata `CancellationError` aparte de los demás errores, sin mostrar mensaje al usuario.
- **Swift 6.4:** `withTaskCancellationShield { }` oculta la cancelación dentro del bloque. Úsalo solo para limpieza y restauración (`rollback`, `release`, `close`, `remove`, `unlock`), nunca para lógica de negocio. Combínalo con `defer` asíncrono, también nuevo en 6.4:

```swift
let workspace = try await TemporaryWorkspace.create()
defer {
    await withTaskCancellationShield { try? await workspace.remove() }
}
```

- `Task.isCancelled` (estática) respeta el escudo; `task.isCancelled` (de instancia) da el estado real.
- Para proteger una tarea hija, pon el escudo dentro de su cuerpo, no alrededor de `addTask`.
- `Task.hasActiveCancellationShield` sirve para depurar, no para decidir la lógica.

## Sincronización síncrona: Mutex y alternativas

| Escenario | Herramienta |
|---|---|
| Sección crítica corta y síncrona, acceso frecuente | `Mutex` (Synchronization, iOS 18+) |
| Lógica de dominio compleja o `await` dentro | `actor` |
| Antes de iOS 18 | `OSAllocatedUnfairLock` (iOS 16+) |
| Muchas lecturas y pocas escrituras con GCD | Cola concurrente con `.barrier` en las escrituras |

```swift
import Synchronization

final class DownloadMetrics: Sendable {   // Sendable comprobado, sin @unchecked
    private let counters = Mutex<[String: Int]>([:])
    func record(host: String) { counters.withLock { $0[host, default: 0] += 1 } }
    func count(for host: String) -> Int { counters.withLock { $0[host, default: 0] } }
}
```

- `Mutex` bloquea el hilo. Nada de I/O, red, cálculo pesado ni `await` dentro de `withLock`.
- No es reentrante: un `withLock` anidado sobre el mismo `Mutex` es un deadlock seguro.
- En un tipo `@MainActor`, declara el `Mutex` como `nonisolated let` para acceder a él desde otros contextos.

## Carga progresiva

Para mostrar contenido antes de que terminen todas las peticiones, emite secciones con una `AsyncSequence` propia y actualiza el modelo `@MainActor` con cada una:

- Representa lo pendiente con `nil` y lo vacío con `[]`.
- Tras lanzar un error o devolver `nil`, el iterador debe devolver `nil` siempre.
- Si permites recargas simultáneas, cancela la carga anterior o identifica cada petición.
- Limitar hilos no limita peticiones: si necesitas un tope, aplícalo explícitamente. Usa `async let` dentro de una etapa para lo que sea independiente.
- Mide tanto el tiempo hasta el primer contenido útil como el tiempo de carga completa.

## NotificationCenter tipado (iOS 26, Swift 6.2)

Sustituye `addObserver(forName:)` y `userInfo` por mensajes tipados:

- `MainActorMessage`: entrega síncrona en el actor principal, para la interfaz.
- `AsyncMessage`: entrega asíncrona con un observador `@Sendable`.

Implementa `makeMessage()` y `makeNotification()` para convivir con el código que usa `post(name:)`.

Ver también las skills `estado-swiftui` (modelos observables), `ciclo-de-vida-swiftui` (`.task`, `.refreshable`) y `memoria-swift`.
