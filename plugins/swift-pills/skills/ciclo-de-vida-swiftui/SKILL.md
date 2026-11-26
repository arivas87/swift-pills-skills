---
name: ciclo-de-vida-swiftui
description: "Ciclo de vida de vistas, tareas y escenas en SwiftUI. Cubre cuándo se ejecutan onAppear y onDisappear frente a la vida de @State en TabView, NavigationStack y listas lazy, .task y .task(id:) con cancelación, onChange (variantes de iOS 17, initial y el modificador de Scene con scenePhase), .refreshable que se cancela solo al mutar el estado, Background App Refresh con .backgroundTask y BGTaskScheduler, la pantalla de lanzamiento (UILaunchScreen, requisito de iOS 27 e ITMS-90870) y el Scene Lifecycle obligatorio en iOS 27. Úsala cuando haya peticiones duplicadas al cambiar de pestaña, estado que se pierde o sobrevive donde no debe, tareas canceladas (NSURLErrorCancelled -999) o configuración de tareas en segundo plano."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/conoces-el-concepto-de-identidad-en-task-de-swiftui-cambia-por-completo-como-manejas-operaciones-asincronas/
    - https://www.swiftpills.dev/posts/swiftui-ciclo-de-vida-onappear/
    - https://www.swiftpills.dev/posts/onchange-en-swiftui-guia-completa/
    - https://www.swiftpills.dev/posts/refreshable-task-cancellation-en-swiftui/
    - https://www.swiftpills.dev/posts/background-app-refresh-swiftui/
    - https://www.swiftpills.dev/posts/scene-lifecycle-obligatorio-ios27/
    - https://www.swiftpills.dev/posts/launch-screen-en-swiftui/
  actualizada: 2026-11-25
---

# Ciclo de vida en SwiftUI

## Dos líneas de tiempo independientes

- **Vida del nodo:** la vista se crea una vez por identidad y su `@State` vive con ella.
- **Visibilidad:** `onAppear` y `onDisappear` pueden dispararse muchas veces durante la vida del mismo nodo.

| Contenedor | Al ocultarse | Al volver |
|---|---|---|
| `if` condicional | El nodo se destruye y el estado se pierde | Nodo nuevo |
| `TabView` (iOS 18+, lazy) | `onDisappear`, el nodo sigue vivo | `onAppear`, estado intacto |
| `NavigationStack` raíz al hacer push | `onDisappear`, el nodo sigue vivo | Estado intacto |
| `NavigationStack` detalle al hacer pop | El nodo se destruye | Nodo nuevo con `@State` desde cero |
| `List` / `LazyVStack` | Las filas lejanas pueden destruirse | El estado local de la fila se reinicia |

- El estado que debe sobrevivir al scroll, como las filas expandidas, va en el modelo (`expandedIDs: Set<ID>`), no en un `@State` de la fila.
- El `init` de una vista no es un evento del ciclo de vida. El orden es `body`, después `onAppear` y después `task`. `body` debe manejar el estado vacío inicial: nada de `events[0]` antes de cargar.
- Para evitar peticiones repetidas en cada cambio de pestaña, usa un enum de carga (`idle`, `loading`, `loaded`, `failed`) con `guard fetchState == .idle` dentro de `.task`, o un `@State hasLoaded`. El flag sobrevive al cambio de pestaña y se reinicia al hacer pop.

## .task

- Crea una tarea ligada a la vista que se cancela al desaparecer.
- Usa `.task(id: valor)` cuando la tarea dependa de un valor: SwiftUI cancela la anterior y lanza una nueva cuando el valor cambia. Sin `id`, la tarea vieja sigue con datos obsoletos.
- Cambiar `.id()` de la vista cancela y reinicia sus tareas.
- Comprueba `Task.isCancelled` o `checkCancellation()` entre etapas y trata `CancellationError` sin mostrar error.

## onChange

- Desde iOS 17, `.onChange(of: v) { }` (lee `v` ya actualizado) y `.onChange(of: v) { old, new in }`. La variante de un parámetro está obsoleta.
- **Trampa al migrar:** en la API antigua `[v]` capturaba el valor anterior; en la nueva captura el nuevo.
- Con `initial: true` se ejecuta al aparecer; en esa primera llamada `old == new`.
- Para valores globales, aplícalo a la `Scene`: `.onChange(of: scenePhase) { _, new in if new == .background { save() } }`.
- Úsalo para efectos hacia fuera (servicios, persistencia, audio). Para derivar estado usa propiedades calculadas: encadenar `@State` crea ciclos. Para trabajo pesado, lanza `Task { }`.

## .refreshable

SwiftUI controla la tarea de `.refreshable`: si su bloque muta el estado que redibuja la vista (`removeAll()`, `append` uno a uno o `isLoading = true` en un `@Observable`), la tarea puede cancelarse a medias y las peticiones fallan con `NSURLErrorCancelled` (-999).

```swift
// Opción por defecto: acumular en local y asignar una vez
.refreshable { episodes = (try? await service.fetchLatest()) ?? [] }

// Si la carga progresiva es imprescindible: tarea no estructurada esperada
.refreshable { await Task { await reloadProgressively() }.value }
```

Sin `await ... .value`, el indicador desaparece en el acto. Diagnostica con la plantilla Swift Concurrency de Instruments.

## Background App Refresh

1. En Signing & Capabilities, activa Background Modes → Background fetch.
2. En el Info.plist, añade `BGTaskSchedulerPermittedIdentifiers` con `com.example.App.refresh`. El identificador debe coincidir exactamente en los tres sitios.
3. Registra el handler en la `Scene`:

```swift
WindowGroup { RootView().task { await store.load() } }
    .backgroundTask(.appRefresh("com.example.App.refresh")) {
        await store.refreshSafely()
        store.scheduleBackgroundRefresh()   // volver a programar: no es recurrente
    }

func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.App.refresh")
    request.earliestBeginDate = Calendar.current.nextDate(after: .now,
        matching: DateComponents(hour: 7, minute: 30), matchingPolicy: .nextTime)
    try? BGTaskScheduler.shared.submit(request)
}
```

- Es una solicitud, no una alarma: iOS decide cuándo y si se ejecuta. La app debe funcionar sin ella: carga primero la caché y refresca en primer plano si hace falta.
- El trabajo debe ser corto. Para descargas largas usa una `URLSession` en segundo plano; para tareas costosas, `BGProcessingTaskRequest`.
- Ante un fallo no borres la caché, y ante una cancelación termina rápido.
- Para probar, en un dispositivo real: `pendingTaskRequests()` y, en LLDB, `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"..."]`.

## Pantalla de lanzamiento

- **No es una vista SwiftUI:** iOS la dibuja a partir de una configuración estática. No admite animaciones ni lógica.
- Configúrala con `UILaunchScreen` en el Info.plist (`UIColorName`, `UIImageName` del catálogo) o con `UILaunchStoryboardName`.
- Debe parecerse a la primera vista: reutiliza el mismo color. Sin texto.
- Si quieres una presentación animada, hazla con una vista SwiftUI normal, idealmente solo la primera vez (`@AppStorage`) y que el usuario la cierre. Nada de temporizadores.
- Muestra la carga de datos dentro de la interfaz real con `.task` y `ProgressView`.
- **iOS 27:** App Store Connect exige `UILaunchScreen(s)` o `UILaunchStoryboardName(s)`; si falta, la subida falla con `ITMS-90870`. Revisa el Info.plist del producto compilado.
- iOS guarda en caché la pantalla de lanzamiento: borra la app para ver los cambios.

## Scene Lifecycle obligatorio en iOS 27

- Las apps UIKit compiladas con el SDK de iOS 27 deben usar `UIScene` con un `UIWindowSceneDelegate` que cree la `UIWindow`. Un `UIApplicationDelegate` solo ya no basta.
- No decidas el layout por `userInterfaceIdiom` (en iPhone Mirroring sigue siendo `.phone`) ni por la orientación. Usa `traitCollection` o el tamaño real de la escena.
- SwiftUI con `App` y `WindowGroup` ya cumple.

Ver también `estado-swiftui`, `concurrencia-swift` y `migracion-ios-27`.
