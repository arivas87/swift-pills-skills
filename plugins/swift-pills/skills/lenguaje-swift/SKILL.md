---
name: lenguaje-swift
description: "Fundamentos y novedades del lenguaje Swift hasta Swift 6.4. Cubre la elección entre struct y class, enums con valores asociados, indirect y @nonexhaustive, associatedtype, some y any, inout, lazy, inicializadores memberwise (SE-0502), throws tipados, errores de Codable legibles (Swift 6.3), key paths como funciones, enumerated() frente a índices, Sequence y Collection, cadenas Unicode (count frente a utf16), medición de tiempo con ContinuousClock y Duration, anyAppleOS, cross-import overlays, @diagnose, defer con await y otras novedades de Swift 6.4. Úsala para diseñar tipos y APIs en Swift, revisar código del lenguaje, adoptar Swift 6.3 o 6.4, o entender errores de compilación como \"cannot find in scope\" en APIs que unen dos frameworks."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/entiendes-realmente-como-funcionan-los-bucles-for-in-en-swift-la-maquinaria-que-hay-detras-es-fascinante/
    - https://www.swiftpills.dev/posts/valores-por-defecto-en-interpolacion-de-cadenas-de-texto-el-truco-que-no-conocias-en-swift/
    - https://www.swiftpills.dev/posts/confundes-count-con-length-o-usas-metodos-de-nsstring-en-swift-estos-errores-pueden-hacer-anicos-tu-app/
    - https://www.swiftpills.dev/posts/associatedtype-en-swift/
    - https://www.swiftpills.dev/posts/lazy-properties-en-swift-y-sus-trampas-en-swiftui/
    - https://www.swiftpills.dev/posts/inout-en-swift/
    - https://www.swiftpills.dev/posts/enums-en-swift/
    - https://www.swiftpills.dev/posts/enums-como-implementacion-de-protocolos-en-swift/
    - https://www.swiftpills.dev/posts/struct-vs-class/
    - https://www.swiftpills.dev/posts/inicializadores-memberwise-swift-6-4/
    - https://www.swiftpills.dev/posts/errores-codable-legibles-swift-6-3/
    - https://www.swiftpills.dev/posts/throws-tipados-swift-6/
    - https://www.swiftpills.dev/posts/cross-import-overlays-en-swift/
    - https://www.swiftpills.dev/posts/nonexhaustive-enumeraciones-publicas-swift/
    - https://www.swiftpills.dev/posts/key-paths-swift-sustituir-bloques/
    - https://www.swiftpills.dev/posts/enumerated-swift-contador-no-indice/
    - https://www.swiftpills.dev/posts/medir-tiempo-transcurrido-en-swift/
    - https://www.swiftpills.dev/posts/swift-6-4-novedades-articulo-wwdc26/
    - https://www.swiftpills.dev/posts/swift-6-4-novedades/
    - https://www.swiftpills.dev/posts/anyappleos-swift-6-4/
  actualizada: 2026-11-25
---

# Lenguaje Swift

## struct o class

Usa `struct` por defecto y `class` solo cuando necesites **identidad compartida**: recursos como conexiones, Bluetooth, reproductores o bases de datos, coordinadores de estado `@Observable`, interoperabilidad con Objective-C o herencia de `UIViewController`/`NSObject`.

- Un identificador que viene del servidor no es identidad de la app: el modelo sigue siendo `struct`.
- Prefiere protocolos y composición a jerarquías de clases.
- Lo habitual: el dominio en `struct` y los modelos de vista, servicios y controladores de estado en `final class`.

## Enums

- Modela estados con valores asociados para que los estados inválidos sean irrepresentables. Un `ContentState<T>` con `.idle`, `.loading`, `.loaded(T)`, `.empty` y `.error(Error)` es mejor que combinar `isLoading` con varios opcionales.
- Pon la lógica que depende del caso en propiedades calculadas del propio enum.
- `switch` exhaustivo sin `default` dentro de la app: así, añadir un caso rompe la compilación donde hay que actualizar.
- Los raw values `String` con `Codable` mapean directamente los valores del servidor.
- Marca `indirect` solo en los casos recursivos (árboles, JSON), porque cada uno añade una asignación en el heap.
- Un requisito estático fijo se satisface con una constante: `static let priority = .high` en lugar de una propiedad calculada.
- **APIs públicas de paquetes (Swift 6.2.3+, SE-0487):** marca con `@nonexhaustive` las enumeraciones que pueden crecer (errores, estados de protocolo, respuestas). Sus clientes deberán usar `@unknown default`, que sigue avisando de los casos nuevos, a diferencia de `default`. Para migrar una enumeración ya publicada, usa `@nonexhaustive(warn)` primero. No se combina con `@frozen`, no es necesario dentro del mismo paquete y la rama desconocida no debe ser `fatalError`.

## Protocolos con associatedtype, some y any

- Con `associatedtype`, el tipo lo fija quien conforma; con genéricos, quien usa el tipo. Añade restricciones (`associatedtype Record: Identifiable & Sendable`) y extensiones condicionales `where`.
- Un protocolo con tipo asociado no se usa como tipo concreto. Usa una restricción genérica, `some P` (tipo opaco fijo), `any P` (existencial, con coste explícito) o un type eraser `AnyP` si necesitas heterogeneidad.
- Swift 6.4 permite escribir `any P?` sin paréntesis.

## inout, mutating y lazy

- `inout` es copy-in copy-out, no paso por referencia. `&` en la llamada avisa de la mutación.
- Pasar la misma variable dos veces como `inout` es un error de exclusividad. Un closure que escapa no puede capturar un parámetro `inout`.
- Usa `inout` cuando la mutación sea el contrato (`normalizar(&texto)`) y un valor de retorno cuando sea una transformación (`normalizando(texto)`). `mutating` equivale a un `self` `inout`.
- `lazy var` calcula el valor en el primer acceso y puede usar `self`. No es seguro con concurrencia: dos hilos pueden inicializarlo a la vez.
- `lazy` no compila en vistas SwiftUI (`body` no muta). Usa `@State` con un objeto `@Observable`, o pon el `lazy` dentro de una clase auxiliar.
- Elige `lazy` para valores caros que no cambian y no siempre se usan, y una propiedad calculada si el valor cambia.

## Inicializadores memberwise

- Las `var` con valor inicial entran en el memberwise con argumento por defecto; las `let` con valor no entran.
- **Swift 6.4 (SE-0502):** las propiedades menos accesibles que el init y que ya tienen valor (`private var cache: String?`) quedan fuera, en vez de volverlo `private`. Las `private(set)` siguen dentro.
- El memberwise es como mucho `internal`. Los tipos públicos necesitan `public init` explícito.
- Para conservar el memberwise y añadir otro init, declara el nuevo en una extensión.

## Errores

**Throws tipados (SE-0413):** `throws(DocumentImportError)` permite `throw .emptyDocument` y un `catch` con `switch` exhaustivo.

- `throws` equivale a `throws(any Error)`, y una función normal a `throws(Never)`.
- Úsalos dentro de un módulo, en código genérico que propaga errores (`(Input) throws(Failure) -> Output`) y en Embedded Swift. Evítalos en APIs públicas que puedan evolucionar.
- Solo admiten un tipo de error. Para varias causas, traduce a un enum de dominio.
- Los closures literales pueden perder el tipo y pasar a `any Error`: pasa una referencia a función o anota el tipo del closure. `do throws(E) { }` delimita el tipo dentro de un bloque.

**Codable (Swift 6.3, SE-0489):** `print(error)` muestra `DecodingError.typeMismatch: expected value of type Int. Path: departures[1].platform`.

- No analices ese texto ni lo uses en tests: inspecciona el caso (`keyNotFound`, `typeMismatch`, `valueNotFound`, `dataCorrupted`) y `context.codingPath`.
- El formato nuevo depende del sistema donde se ejecuta. Si necesitas una salida uniforme, escribe tu propio formateador.
- No registres el documento entero.
- Haz opcional una propiedad solo si el contrato real lo es.

**Swift 6.4:** avisa de los `Task { try await ... }` cuyo error se pierde. Captura el error dentro o guarda la tarea y espera `task.value`.

## Colecciones e iteración

- `for-in` usa `Sequence.makeIterator()` y `next()`.
- `Collection` permite varias pasadas e índices, `BidirectionalCollection` recorrer hacia atrás, y `RandomAccessCollection` mover índices en O(1). `String.count` es O(n).
- `enumerated()` da un **contador** (`offset`), no un índice. En un `ArraySlice` (`stages[2...]`) los índices empiezan en 2. Para posiciones usa `indices` o `zip(c.indices, c)`, e `index(_:offsetBy:)` para convertir una distancia.
- En `ForEach`, la identidad debe ser el `id` del elemento, nunca el offset: `ForEach(Array(items.enumerated()), id: \.element.id)`.
- Los literales de key path sirven como funciones: `map(\.name)`, `compactMap(\.lastReading)`, `filter(\.isOnline)`, `first(where: \.isOnline)`. La conversión solo se aplica al literal (`let f: (Sensor) -> String = \.name`). Mantén el closure para negaciones, cálculos y `sorted(by:)`.
- Swift 6.4 añade `mapKeyedValues` en diccionarios y, con `import Containers`, `UniqueArray` y `RigidArray` para elementos `~Copyable`, junto a `Iterable` para iterar por préstamo.

## Cadenas y Unicode

- `String.count` cuenta grafemas: un emoji con ZWJ o un modificador de tono cuenta como un solo `Character`.
- Las APIs de Objective-C (`NSRegularExpression`, `NSDataDetector`, `UITextChecker`, `NSRange`) trabajan en UTF-16: usa `utf16.count`, nunca `count` ni `NSString.length` mezclados.
- Usa `replacing(_:with:)` en lugar de `replacingOccurrences(of:with:)`, que puede romper banderas. Usa `compactMap` para descartar `nil`.
- Interpolación con valor por defecto para opcionales: `"Hola \(nombre, default: "Invitado")"`, nativo desde Swift 6.2 o con una extensión de `String.StringInterpolation`.

## Medir tiempo

- No uses `Date` para medir duraciones, porque el reloj del sistema se puede ajustar. Usa `ContinuousClock().measure { }`, también con `await`, que devuelve un `Duration`.
- `SuspendingClock` no cuenta el tiempo en reposo. Para obtener resultado y duración, usa `clock.now` y `start.duration(to: clock.now)`.
- Mantén el valor como `Duration` (`.milliseconds(750)`) y formatéalo con `.formatted(.units(...))` o `.time(pattern:)`.
- Una medición no es un benchmark: usa `measure(metrics: [XCTClockMetric()])` en tests e Instruments para investigar.

## Disponibilidad y módulos

- **Swift 6.4:** `@available(anyAppleOS 26.0, *)` y `#available(anyAppleOS 26.0, *)` solo admiten versiones 26 o posteriores. Se puede refinar por plataforma (`@available(anyAppleOS 26.0, watchOS 26.2, *)`, `@available(tvOS, unavailable)`). `#if os(anyAppleOS)` es de compilación y no sustituye a `canImport`. No cambia `platforms` en `Package.swift`.
- **Cross-import overlays:** algunas APIs solo existen si el **mismo archivo** importa los dos módulos. Por ejemplo, `Map` necesita SwiftUI y MapKit; `PhotosPicker`, SwiftUI y PhotosUI; `WebView`, SwiftUI y WebKit; `VideoPlayer`, SwiftUI y AVKit; `.quickLookPreview`, SwiftUI y QuickLook. Ante un "cannot find in scope" en una API documentada, añade el segundo `import` antes de tocar DerivedData. Nunca importes módulos `_Interno_SwiftUI`.
- **Selectores de módulo (Swift 6.3):** `SwiftUI::View` resuelve conflictos de nombres entre módulos.

## Otras novedades de Swift 6.4

- `defer { await session.end() }`. Si la limpieza no debe cancelarse, envuélvela en `withTaskCancellationShield` (ver `concurrencia-swift`).
- `@diagnose(DeprecatedDeclaration, as: ignored, reason: "...")` ajusta un grupo de avisos en una sola declaración. No oculta errores.
- `weak let` para referencias débiles inmutables: permite clases `Sendable` sin `@unchecked`. `~Sendable` declara que un tipo no es `Sendable`.
- `@inline(always)` y `@specialized` solo tras medir.
- Swift Testing y XCTest interoperan: `#expect` funciona en `XCTestCase` y `Test.cancel()` cancela una prueba.

Ver también `memoria-swift` y `concurrencia-swift`.
