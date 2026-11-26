---
name: rendimiento-swiftui
description: "Rendimiento de SwiftUI y cómo evitar reevaluaciones de body innecesarias. Cubre la composición en subvistas con dependencias pequeñas, la identidad estructural frente a la explícita, @ViewBuilder frente a AnyView, cuándo cada tipo de entrada (propiedad, @State, @Binding, @Environment, @Observable, ObservableObject) vuelve a evaluar body, propiedades Equatable en modelos @Observable, valores por defecto inestables en @Entry (aviso de Xcode 27), ForEach con un número variable de vistas por elemento (-LogForEachSlowPath), geometryGroup frente a compositingGroup y drawingGroup, y el coste real de @State y los structs. Úsala al optimizar listas, pantallas lentas o animaciones con tirones, o al revisar el diseño de las vistas."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/composicion-en-swiftui/
    - https://www.swiftpills.dev/posts/valores-por-defecto-inestables-environment-swiftui/
    - https://www.swiftpills.dev/posts/propiedades-equatable-clases-observable-swiftui/
    - https://www.swiftpills.dev/posts/geometry-compositing-drawing-group-swiftui/
    - https://www.swiftpills.dev/posts/dependencias-de-datos-en-swiftui-y-actualizaciones-de-body/
    - https://www.swiftpills.dev/posts/foreach-rendimiento-contenedores-lazy-swiftui/
    - https://www.swiftpills.dev/posts/swiftui-state-structs-coste-memoria/
  actualizada: 2026-11-25
---

# Rendimiento en SwiftUI

Volver a evaluar `body` no es volver a dibujar. El objetivo es que cada vista dependa solo de lo que usa y que su `body` sea barato, no que se ejecute una sola vez. **Mide antes de optimizar:** instrumento SwiftUI de Instruments en Release (actualizaciones largas de `body`, grafo de causa y efecto), Time Profiler y `let _ = Self._printChanges()` (o `expression Self._printChanges()` en LLDB) solo para diagnosticar.

## Qué provoca otra evaluación de body

| Entrada | Cuándo invalida |
|---|---|
| Propiedad almacenada | Cuando cambia el valor o la referencia, **aunque `body` no la use** |
| Closure pasado como propiedad | Casi siempre: SwiftUI no puede comparar closures |
| `@State` / `@Binding` | Después de leerlo en `body`; la dependencia dura lo que dure la identidad |
| `@Environment` / `@FocusedValue` | Basta con **declararlo**, aunque no se lea |
| Modelo `@Observable` | Cuando cambia una propiedad leída en la última evaluación |
| `ObservableObject` | Con cualquier `objectWillChange`, se lea o no la propiedad |

Consecuencias:

- Pasa a cada subvista solo los datos que usa. No le pases el modelo entero a una fila que solo muestra un nombre.
- Quita las propiedades y los `@Environment` que ya no se usan.
- No arrastres closures por niveles que no los necesitan.
- Si una rama grande lee un binding, muévela a su propia vista.
- Migrar a `@Observable` reduce invalidaciones frente a `ObservableObject`.
- No hagas trabajo en `body`: filtrar, ordenar, formatear o asignar colecciones grandes va fuera.

## Composición e identidad

- Extrae componentes que tengan una responsabilidad con nombre y entradas claras, no uno por cada `Text`.
- **Identidad estructural:** si dos ramas de un `if` son dos estados de la misma vista, conserva una sola vista y varía sus modificadores. Así preservas el estado y las animaciones. Usa ramas solo para vistas que son conceptualmente distintas.

```swift
// En lugar de if/else con dos ClimateBadge
ClimateBadge(title: isEco ? "Modo eficiente" : "Modo normal")
    .foregroundStyle(isEco ? .green : .primary)
```

- Usa `@ViewBuilder` y genéricos (`struct Panel<Content: View>`, `@ViewBuilder let content: Content`) en lugar de `AnyView`. `AnyView` solo tiene sentido tras fronteras dinámicas de verdad.
- `Group` comparte modificadores, pero no hace layout. Si necesitas eje o espaciado, usa un stack.

## ForEach en contenedores lazy

- Cada elemento debe producir **un número constante de vistas**. Activa `-LogForEachSlowPath YES` en Run → Arguments para detectar el problema.
- Para excluir elementos, **filtra los datos** antes del `ForEach`, nunca con un `if` dentro. Envolver el `if` en un `VStack` deja filas vacías.
- Si el contenido de un elemento es opcional, envuélvelo en un contenedor estable: `ForEach { VStack { nombre; if let aviso { ... } } }`.
- Guarda la colección filtrada en el modelo y recalcúlala solo cuando cambien los datos: una propiedad calculada se vuelve a evaluar en cada `body`.
- Identifica con un `id` estable, nunca con offsets ni índices.

## Equatable en modelos @Observable

- El setter de `@Observable` no notifica si el valor nuevo es `==` al anterior, pero **solo si el tipo es `Equatable`**. Sin `Equatable`, cada asignación notifica.
- Una clase no `Equatable` solo notifica si cambia la referencia.
- Conforma a `Equatable` los snapshots y modelos que llegan repetidos por polling, streams o sincronización. `[Album]` solo es `Equatable` si `Album` lo es.
- Las mutaciones in situ (`append`, `sort`) notifican siempre. Si es probable que el resultado no cambie, calcula aparte y asigna: `albums = albums.sorted(...)`.
- No falsees `==` ignorando campos visibles: la interfaz se quedaría congelada. Separa los metadatos en otra propiedad o márcalos con `@ObservationIgnored`.
- Comparar colecciones grandes cuesta. Mide antes de decidir.

## Valores por defecto en @Entry

La expresión por defecto de `@Entry` se evalúa en cada acceso sin valor inyectado. Si crea una instancia nueva (clase, `UUID()`, `Date()` o un struct que contiene una clase), SwiftUI ve un entorno distinto en cada consulta e invalida las vistas que lo declaran. Xcode 27 avisa en el caso de las clases.

```swift
// MAL
extension EnvironmentValues { @Entry var thumbnails = ThumbnailRepository() }

// BIEN: instancia estable
private let defaultThumbnails = ThumbnailRepository()
extension EnvironmentValues { @Entry var thumbnails = defaultThumbnails }

// BIEN: inyección obligatoria
extension EnvironmentValues { @Entry var thumbnails: ThumbnailRepository? }
```

Inyectar siempre desde la raíz esconde el síntoma, pero el problema reaparece en previews, tests o ramas nuevas de la navegación. Corrige la declaración.

## geometryGroup, compositingGroup y drawingGroup

| Problema | Modificador |
|---|---|
| Las piezas se separan mientras el contenedor anima posición o tamaño (iOS 17+) | `.geometryGroup()` antes del `frame` o la alineación que cambia |
| La opacidad, una mezcla o una sombra se aplica a cada hijo y se ven las intersecciones | `.compositingGroup()` **antes** de `.opacity()`; el orden importa |
| Un gráfico con muchísimas operaciones de dibujo es caro según Instruments | `.drawingGroup(opaque: false, colorMode: .linear)` |

- `drawingGroup` rasteriza fuera de pantalla: consume memoria y se regenera con cada cambio. No sirve con vistas de UIKit o AppKit, web ni vídeo. No es una optimización preventiva.
- `opaque: true` solo si todos los píxeles son opacos.

## Coste de @State y los structs

- Una vista es una descripción temporal: su `@State` vive asociado a la identidad, no al struct. Crear valores de vista es barato, y `MemoryLayout` no mide el coste real.
- Declara como `@State` solo los valores que la vista modifica y conserva. El resto son entradas o propiedades calculadas.
- Desde Xcode 27, la expresión inicial de `@State` se evalúa una vez por identidad, incluso desplegando en iOS 17.
- Para comparar implementaciones, usa Allocations y VM Tracker en Release con la misma secuencia de interacción.

Ver también `estado-swiftui` y `animaciones-swiftui`.
