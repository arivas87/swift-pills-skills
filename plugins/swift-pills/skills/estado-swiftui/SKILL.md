---
name: estado-swiftui
description: "Flujo de datos y estado en SwiftUI con Observation. Cubre dónde poner la fuente de verdad (@State, @Binding, let, @Environment, @Bindable), modelos @Observable y su inicialización, por qué @State no se actualiza desde el padre, @State como macro en Xcode 27, bindings personalizados con subscripts frente a Binding(get:set:), MVVM sin sobreingeniería, componentes compartidos con demasiados booleanos, withContinuousObservation y Observations fuera de SwiftUI, y Observation en UIKit con updateProperties(). Úsala al diseñar el estado de una pantalla SwiftUI, al depurar vistas que no se actualizan o que reinician su estado, o al decidir si una vista necesita un ViewModel."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/tus-vistas-de-swiftui-parecen-novelas-interminables-la-arquitectura-es-la-solucion/
    - https://www.swiftpills.dev/posts/uikit-ahora-puede-observar-cambios-de-estado-automaticamente-como-swiftui-adios-al-codigo-manual/
    - https://www.swiftpills.dev/posts/inicializas-correctamente-tus-clases-observable-en-swiftui-algnos-errores-pueden-romper-tu-app/
    - https://www.swiftpills.dev/posts/por-que-state-en-swiftui-no-se-actualiza-desde-la-vista-padre-este-error-confunde-hasta-a-desarrolladores-avanzados/
    - https://www.swiftpills.dev/posts/estado-en-swiftui-fuentes-de-verdad-observation-y-errores-comunes/
    - https://www.swiftpills.dev/posts/state-es-una-macro-ahora/
    - https://www.swiftpills.dev/posts/bindings-personalizados-swiftui-closures-vs-subscripts/
    - https://www.swiftpills.dev/posts/withcontinuousobservation-observacion-continua-swift/
    - https://www.swiftpills.dev/posts/mvvm-swiftui-sin-sobreingenieria/
    - https://www.swiftpills.dev/posts/componentes-compartidos-swift-responsabilidades/
  actualizada: 2026-11-25
---

# Estado en SwiftUI

## Regla base: cada dato tiene un único propietario

| La vista... | Usa |
|---|---|
| Solo lee un valor | `let` |
| Edita un valor que pertenece a otra vista | `@Binding` |
| Es la dueña de un valor local (foco, hoja abierta, borrador) | `@State private var` |
| Crea y es dueña de un modelo `@Observable` | `@State private var model = Model()` |
| Recibe un modelo `@Observable` | `let model: Model`; usa `@Bindable var model = model` dentro de `body` si necesitas `$model.prop` |
| Comparte una dependencia amplia (sesión, configuración) | `.environment(obj)` y `@Environment(Model.self)` |

- Elige el alcance más pequeño: un control, una sección, una pantalla (modelo observable) o toda la app (entorno). No promociones el estado a global demasiado pronto ni uses el entorno para ahorrarte dos parámetros.
- Separa el estado de interfaz (hoja abierta, foco, modo edición) del estado de dominio (libro leído, pago confirmado).
- Para un objeto observable no hace falta un `Binding`: pasa la referencia y modifica sus propiedades.
- Con `ObservableObject`, para versiones anteriores a iOS 17, las equivalencias son `@StateObject`, `@ObservedObject` y `@EnvironmentObject`. `@Observable` solo invalida las vistas que leen la propiedad que cambia.

## Errores frecuentes

**Un `@State` que recibe un valor desde fuera.** `@State var name: String` en una vista hija se queda con el primer valor: el estado se asocia a la identidad de la vista y los inits posteriores se ignoran. Usa `@Binding` si el padre manda, o `let` si solo se lee.

```swift
// MAL: el hijo edita su propia copia
struct BookEditor: View { @State var book: Book }
// BIEN
struct BookEditor: View {
    @Binding var book: Book
    var body: some View { TextField("Título", text: $book.title) }
}
```

- Si de verdad es un valor inicial, nómbralo así: `init(defaultGoal:)` con `_currentGoal = State(initialValue: defaultGoal)`.
- **Un modelo `@Observable` sin `@State`.** `let counter = Counter()` en una vista se recrea cada vez que el padre reconstruye `body`, y el estado se pierde.
- **`.id(...)` para forzar actualizaciones.** Destruye y recrea el subárbol y su estado. Úsalo solo cuando quieras reiniciar de verdad, por ejemplo un editor al cambiar de documento. Si una actualización no llega, revisa quién es el dueño del dato.
- **Modelos que dependen de un parámetro.** Crear `@State private var store = Store(id: userID)` en el `init` no se actualiza cuando cambia `userID`. Usa `.task(id: userID) { store = Store(id: userID) }`, estado derivado, inyección o `.id(userID)`.

## Inicialización de @State con objetos

- Inicializa en la declaración (`@State private var store = UserStore()`), no en el `init` de la vista: el `init` se ejecuta muchas veces y cada instancia descartada ejecuta igualmente su inicializador.
- **Hasta Xcode 26**, la expresión de `@State` se evaluaba en cada recreación de la vista y las instancias sobrantes se descartaban. Para modelos caros, el patrón era un opcional creado en `.task`:

```swift
@State private var model: HeavyModel?
var body: some View {
    content.task { if model == nil { model = HeavyModel() } }
}
```

- **En Xcode 27, `@State` es una macro** con inicialización diferida: la expresión solo se evalúa al crear el almacenamiento real. El patrón del opcional ya no hace falta si el único objetivo era evitar inicializaciones repetidas.
- El estado global de todas las escenas va en el `App` y se pasa con `.environment`. Lo que se crea dentro de `WindowGroup` es independiente en cada ventana.

## Bindings personalizados

- `Binding(get:set:)` está bien para adaptaciones puntuales, como `draft.alias ?? ""`.
- En listas, prefiere un `subscript` en el modelo con proyección por key path: SwiftUI recibe una ruta estable en lugar de closures nuevos en cada evaluación de `body`.

```swift
@MainActor @Observable
final class OfflineMapsModel {
    var downloadedRegionIDs: Set<MapRegion.ID> = []
    subscript(isAvailableOffline id: MapRegion.ID) -> Bool {
        get { downloadedRegionIDs.contains(id) }
        set { if newValue { downloadedRegionIDs.insert(id) } else { downloadedRegionIDs.remove(id) } }
    }
}

ForEach(regions) { region in
    MapRegionRow(region: region, isAvailableOffline: $model[isAvailableOffline: region.id])
}
```

- El argumento del subscript debe ser un identificador estable, nunca un índice de array.
- Los setters de un binding deben ser síncronos y rápidos: nada de red ni de disco.
- Un `Set` sigue siendo una sola dependencia observada. Si necesitas granularidad por elemento, dale a cada fila un modelo observable propio.
- Diagnostica con `let _ = Self._printChanges()` dentro de `body` y con el instrumento SwiftUI en una compilación Release.

## MVVM sin sobreingeniería

- Empieza sin ViewModel. Extráelo cuando haya lógica de presentación que merezca probarse aparte: carga asíncrona, varias dependencias, estados de carga y error, validación o transformación de datos.
- Un ViewModel adapta el dominio a la pantalla. No conoce su `View`, y la red, la persistencia y las reglas de dominio van en servicios inyectados por protocolo.
- Usa `@Observable @MainActor final class`, con acciones con intención (`save()`), estado `private(set)` y un enum de estado (`idle`, `saving`, `saved`, `failed(String)`). Trata `CancellationError` aparte.
- Prueba el comportamiento con un doble del servicio (un actor espía) y `@Test @MainActor`, sin representar la vista.

## Componentes compartidos

- Si un componente acumula booleanos (`showFavorite`, `showSubscription`) que cada pantalla activa o desactiva por su cuenta, separa las responsabilidades: deja una base común y compón las diferencias en cada contexto con `overlay` o modificadores.
- En lógica de negocio, dos funciones con nombre propio (`historicalPages`, `pagesForToday`) son mejor que una con flags de opciones.
- Cambiar los booleanos por un enum limita las combinaciones, pero no separa las responsabilidades. A veces es mejor volver a duplicar.
- Divide los `body` largos en vistas con una sola responsabilidad. Para estilos repetidos usa `ViewModifier` y para layouts repetidos, extensiones de `View`.

## Observation fuera de SwiftUI

| Necesidad | API |
|---|---|
| Una vista SwiftUI | Automático: basta con leer en `body` |
| Consumir cambios agrupados con `for await` | `Observations` (Swift 6.2) |
| Reaccionar una sola vez con `willSet`, `didSet` o `deinit` | `withObservationTracking(options:_:onChange:)` (Swift 6.4) |
| Reaccionar durante toda la vida de un controlador o servicio | `withContinuousObservation` (Swift 6.4, SE-0506) |

```swift
@MainActor
final class AudioController {
    private let preferences: AudioPreferences
    private var token: ObservationTracking.Token?   // la observación vive lo que viva el token

    init(preferences: AudioPreferences) {
        self.preferences = preferences
        token = withContinuousObservation(options: [.didSet]) { [weak self] event in
            guard let self else { event.cancel(); return }
            let volume = self.preferences.volume        // leer registra la dependencia
            let muted = self.preferences.isMuted
            if event.kind == .initial || event.matches(\AudioPreferences.volume)
                || event.matches(\AudioPreferences.isMuted) {
                self.apply(volume: volume, muted: muted)
            }
        }
    }
}
```

- El primer evento siempre es `.initial`.
- Las dependencias son las propiedades leídas en cada ejecución. Un `guard` o `return` temprano deja fuera las que no se llegan a leer.
- El bloque se ejecuta en el aislamiento desde el que se inició la observación.
- `token = nil` detiene la observación. En los SDK 27 es una API beta.

**UIKit (iOS 26):** lee propiedades `@Observable` dentro de `updateProperties()` y UIKit invalida la vista automáticamente. En iOS 18 se activa con `UIObservationTrackingEnabled` en el Info.plist, leyendo en `viewWillLayoutSubviews()`.

Ver también `rendimiento-swiftui`, `ciclo-de-vida-swiftui` y `concurrencia-swift`.
