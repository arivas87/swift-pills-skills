---
name: memoria-swift
description: "Gestión de memoria en Swift con ARC. Cubre referencias strong, weak, unowned y unowned(unsafe), ciclos de retención en closures, capturas [weak self] anidadas (el aviso de Swift 6.4), side tables, la diferencia entre stack y heap, copy-on-write, autoreleasepool, tipos ~Copyable con borrowing y consuming, y la comparación con el ownership de Rust. Úsala para escribir o revisar código con clases, closures que escapan, delegates, cachés débiles o bucles que crean muchos objetos, y para investigar fugas de memoria o deinit que no se llama."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/autoreleasepool-en-swift-un-vestigio-del-pasado-o-una-herramienta-esencial/
    - https://www.swiftpills.dev/posts/arc-en-swift/
    - https://www.swiftpills.dev/posts/stack-vs-heap-en-swift/
    - https://www.swiftpills.dev/posts/arc-de-zombie-objects-a-side-tables/
    - https://www.swiftpills.dev/posts/modelo-de-memoria-rust-vs-swift/
    - https://www.swiftpills.dev/posts/swift-6-4-capturas-weak-anidadas/
  actualizada: 2026-11-25
---

# Memoria en Swift

## Elegir el tipo de referencia

Empieza por la propiedad, no por el rendimiento.

| Relación | Referencia | Contrato |
|---|---|---|
| A posee a B | `strong` (por defecto) | B vive mientras A lo retenga |
| B puede desaparecer y su ausencia es válida (delegates, observers, coordinadores, cachés) | `weak var` | Puede ser `nil`; ARC la anula sola |
| B vive siempre más que A por construcción y se puede documentar | `unowned let` | Acceder a un objeto ya destruido provoca un crash controlado |
| Rendimiento extremo, rigurosamente controlado | `unowned(unsafe)` | Sin comprobaciones: memoria corrupta o segfault. No usar en código de app |

- Los protocolos de delegate deben ser `AnyObject` para poder declararlos `weak`.
- En la duda entre `weak` y `unowned`, elige `weak`. Un ciclo de vida que hoy parece obvio puede romperse meses después con un refactor, y entonces `unowned` se convierte en un crash.
- Los tipos `@Observable` son clases: se aplican las mismas reglas de ciclos.

## Closures y ciclos de retención

- Un closure almacenado por un objeto que captura ese objeto forma un ciclo. Usa `[weak self]` y `guard let self else { return }`.
- **`[weak self]` solo afecta al closure donde se escribe.** Si está en un closure interior, el exterior captura `self` fuerte de forma implícita para poder crear la captura débil. Swift 6.4 (Xcode 27) avisa con `'weak' ownership of capture 'self' differs from implicitly-captured strong reference in outer scope`.

```swift
// MAL: el closure exterior (guardado por monitor, que es de self) retiene a self
monitor.onRegionChange = { [service] region in
    service.fetchForecast(for: region) { [weak self] forecast in
        self?.headline = forecast.summary
    }
}

// BIEN: la captura débil va en el closure que escapa y se almacena
monitor.onRegionChange = { [weak self, service] region in
    service.fetchForecast(for: region) { forecast in
        self?.headline = forecast.summary
    }
}

// BIEN: si el exterior necesita self, débil en ambos niveles
monitor.onRegionChange = { [weak self] region in
    guard let self else { return }
    self.recordRegionChange(region)
    self.service.fetchForecast(for: region) { [weak self] forecast in
        self?.headline = forecast.summary
    }
}

// BIEN: captura fuerte intencionada en un closure de vida breve que no retiene self
workerQueue.async { [self] in
    service.fetchForecast(for: selectedRegion) { [weak self] in self?.headline = $0.summary }
}
```

- No silencies el aviso con `[weak self = self]` ni cambiando a `unowned` sin revisar quién retiene cada closure: puede convertir una fuga en un crash.
- Para decidir, sigue la traza: quién conserva el closure exterior, cuánto tiempo, y si hay un camino de vuelta al objeto capturado. Un closure que no escapa no forma ciclos duraderos.

## Cómo funciona ARC por dentro

- El compilador inserta `swift_retain`/`swift_release` y los optimiza: elimina redundancias, adelanta el release al último uso y usa análisis de escape. `deinit` es determinista: se ejecuta cuando el contador llega a cero, así que sirve para cerrar ficheros, sockets o conexiones.
- Desde Swift 4, las referencias débiles apuntan a una *side table* que se crea con la primera referencia `weak`. El objeto se libera en cuanto cae la última referencia fuerte, aunque queden referencias débiles. El modelo antiguo de objetos zombie ya no existe.
- Coste: strong es lo más barato. `weak` añade indirección, peor localidad de caché y una retención temporal en cada lectura; además, en cuanto existe la side table, también las operaciones fuertes pasan por ella. `unowned` evita la side table, pero comprueba en cada acceso que el objeto sigue vivo.
- Para guardar referencias débiles en colecciones, usa una caja:

```swift
final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
```

## Stack, heap y semántica

- La regla de que los struct van al stack y las clases al heap es falsa en la práctica. Razona por semántica: los tipos de valor (`struct`, `enum`, tuplas) dan copias independientes, y los de referencia (`class`, `actor`, closures) dan identidad compartida. La ubicación la decide el compilador.
- Un `struct` almacenado en una clase vive en el heap, dentro del objeto. `Array`, `Dictionary` y `String` tienen semántica de valor, pero guardan sus datos en un búfer en el heap con copy-on-write: solo copian al mutar una copia compartida.
- El análisis de escape puede llevar al stack objetos que no escapan. `final` ayuda al eliminar el dispatch dinámico.
- Los tres costes reales son la asignación en el heap, las operaciones atómicas de retain y release, y la localidad de caché. Mídelos con Instruments (Allocations) antes de optimizar.

## autoreleasepool

Sigue siendo útil con APIs de Objective-C (Core Image, AVFoundation, PDFKit, Core Graphics) que devuelven objetos autoreleased:

- En bucles que crean muchos objetos temporales, envuelve cada iteración en `autoreleasepool { }`.
- Las colas en segundo plano (`DispatchQueue.global()`) no vacían pools por run loop; crea uno por iteración.
- En herramientas de línea de comandos, sin pool los objetos no se liberan hasta que termina el proceso.
- No lo pongas por defecto: mide con Instruments y úsalo solo donde reduzca los picos de memoria.

```swift
for url in urls {
    autoreleasepool {
        guard let document = PDFDocument(url: url) else { return }
        save(extractText(from: document))
    }
}
```

## Ownership explícito: ~Copyable

Para recursos con propietario único (descriptores, bloqueos, tokens) declara el tipo `~Copyable`. `borrowing` da acceso temporal, `consuming` transfiere la propiedad e `inout` permite una mutación exclusiva. Usar un valor después de consumirlo es un error de compilación.

```swift
struct ExportLease: ~Copyable {
    let identifier: Int
    borrowing func inspect() { print("Exportación \(identifier)") }
    consuming func commit() { print("Confirmando \(identifier)") }
}
```

Equivalencias con Rust: `&T` corresponde a `borrowing`, `&mut T` a `inout`/`mutating`, *move* a `consuming`/`consume`, `Rc`/`Arc` a una clase con ARC, `Weak<T>` a `weak`/`unowned` y `Drop` a `deinit`. ARC decide cuándo se destruye una instancia, no quién puede mutarla: para concurrencia hacen falta `Sendable`, actores y aislamiento (ver la skill `concurrencia-swift`).

## Diagnóstico

- Memory Graph Debugger de Xcode para ver ciclos, Instruments con Leaks y Allocations, y Malloc Stack Logging para saber dónde se creó un objeto que nunca se libera.
- Un `print` temporal en `deinit` es la comprobación más rápida durante el desarrollo.
