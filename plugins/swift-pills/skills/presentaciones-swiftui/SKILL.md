---
name: presentaciones-swiftui
description: "Presentaciones, navegación y barras de herramientas en SwiftUI. Cubre alert y confirmationDialog con item y error (Xcode 27), varias sheets con un único enum, sheets que se ajustan a la altura del contenido, paneles laterales adaptativos frente a una bottom sheet, presentationSizing y presentationBackgroundInteraction, dismiss desde el entorno correcto, navigationTransition(.crossfade) y las toolbars de iOS 27 (visibilityPriority, ToolbarOverflowMenu, topBarPinnedTrailing, ToolbarSpacer, toolbarMinimizeBehavior). Úsala para sustituir combinaciones de booleanos y opcionales por un estado de presentación único, al diseñar sheets y alertas, o al decidir qué acciones de una toolbar se quedan visibles en ventanas estrechas."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/sheets-swiftui-ajustadas-al-contenido/
    - https://www.swiftpills.dev/posts/navigationtransition-crossfade-swiftui/
    - https://www.swiftpills.dev/posts/presentaciones-item-based-alert-confirmationdialog-swiftui/
    - https://www.swiftpills.dev/posts/alertas-dialogos-datos-swiftui-ios-27/
    - https://www.swiftpills.dev/posts/presentar-varias-sheets-en-swiftui-con-un-enum/
    - https://www.swiftpills.dev/posts/sheets-laterales-swiftui-ios-27/
    - https://www.swiftpills.dev/posts/control-avanzado-toolbar-swiftui/
    - https://www.swiftpills.dev/posts/toolbars-adaptativas-swiftui-ios-27/
  actualizada: 2026-11-25
---

# Presentaciones en SwiftUI

**Regla:** si dos estados cambian siempre juntos, no son dos estados. La presentación debe nacer de un dato opcional: `nil` significa que no hay nada que presentar y un valor contiene todo el contexto.

## Alertas y diálogos con item (Xcode 27)

```swift
@State private var trackToRemove: DownloadedTrack?

.confirmationDialog("Eliminar descarga", item: $trackToRemove, titleVisibility: .visible) { track in
    Button("Eliminar", role: .destructive) { remove(track) }
    Button("Cancelar", role: .cancel) { }
} message: { track in
    Text("\(track.title) dejará de estar disponible sin conexión.")
}

.alert("La parada ya está planificada", item: $conflict) { c in ... } message: { c in ... }
```

- Sustituye la pareja `isPresented` más `presenting:`, que permite estados imposibles. SwiftUI vuelve a poner el binding en `nil` al cerrar.
- **Errores:** `.alert(error: $exportError) { error in ... } message: { error in ... }`. Con `LocalizedError`, `errorDescription` es el título. Ojo: la variante sin `message` recibe un closure **sin** parámetro.
- Para varias alertas excluyentes, usa un enum (`PendingAccountAlert?`) con un `switch` en las acciones y el mensaje.
- El valor debe ser una instantánea inmutable: los cambios mientras se presenta se ignoran.
- Mantén `isPresented` para alertas sin datos asociados.
- Usa `role: .destructive` y `.cancel` en lugar de depender del orden de los botones. En diálogos destructivos, pon `titleVisibility: .visible`.
- **Disponibilidad:** el artículo de junio de 2026 describe estas APIs como iOS 27+ con `item: Identifiable`; el de agosto de 2026 indica que `item` no exige `Identifiable` y que se retroportan hasta iOS 15 con `@backDeployed`. Comprueba la firma en tu SDK. Para la ruta de compatibilidad, deriva un `Binding<Bool>` del opcional (`get: { item != nil }`, `set: { if !$0 { item = nil } }`) y úsalo con `isPresented:presenting:`.

## Varias sheets con un único enum

```swift
enum SheetDestination: Identifiable, View {
    case newStop, filters
    case editStop(Stop)

    enum ID: Hashable { case newStop, filters, editStop(UUID) }
    var id: ID {
        switch self { case .newStop: .newStop; case .filters: .filters; case .editStop(let s): .editStop(s.id) }
    }
    var body: some View {
        switch self {
        case .newStop: NewStopView()
        case .filters: FilterStopsView()
        case .editStop(let stop): EditStopView(stop: stop)
        }
    }
}

@State private var presentedSheet: SheetDestination?
.sheet(item: $presentedSheet) { $0 }
```

- El `id` debe ser estable y único. `var id: UUID { UUID() }` está mal: reinicia la sheet. Sin valores asociados, basta con `var id: Self { self }`.
- Si hay dependencias o módulos de por medio, deja el enum como estado puro y resuelve la vista con una función `@ViewBuilder` en la pantalla que presenta.
- El mismo patrón sirve para `fullScreenCover(item:)` y `popover(item:)`. Usa routers locales a cada pantalla, no uno global.
- Lee `@Environment(\.dismiss)` **dentro** de la vista presentada.

## Sheet ajustada al contenido

```swift
private struct FittingSheetModifier: ViewModifier {
    let extraDetents: Set<PresentationDetent>
    @State private var height: CGFloat = 1               // nunca 0
    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = max(1, $0) }
            .presentationDetents(Set([.height(height)]).union(extraDetents))
    }
}
```

- Va bien para confirmaciones, filtros, selectores y resúmenes. No la uses para listas largas ni para navegación.
- Con Dynamic Type, añade un `ScrollView` o `.large` como detent extra.
- No hagas que el contenido dependa de la altura medida: crearías un bucle.

## Paneles laterales frente a bottom sheet

- `presentationSizing(.form)`, `.page`, `.fitted` y similares controlan el tamaño, no la posición. Una sheet más estrecha no es un panel lateral.
- Para que una bottom sheet pase a panel `trailing` en ventanas anchas, decide por el ancho disponible (`>= 700` o el umbral del componente), nunca por el idiom. Compón con `ZStack` y `.transition(.move(edge:))` y encapsúlalo en un `ViewModifier`.
- Un panel lateral puede ser no modal: inspectores, filtros, herramientas. En una sheet estándar, usa `.presentationBackgroundInteraction(.enabled(upThrough: .height(220)))`.
- Para tareas modales y lineales, mantén la sheet del sistema. En iPhone Duo existe `presentationPlacement` (ver `iphone-duo`).

## Transiciones de navegación

- `.navigationTransition(.crossfade)` en el destino da un fundido discreto, adecuado entre estados de un mismo contexto o cuando se quiere reducir el movimiento.
- `.zoom` junto con `matchedTransitionSource` sirve para dar continuidad visual a un elemento.

## Toolbars adaptativas (iOS 27)

| Nivel | API |
|---|---|
| Acción imprescindible anclada al extremo; solo desborda con búsqueda activa sin espacio | `ToolbarItem(placement: .topBarPinnedTrailing)` |
| Acciones o grupos importantes que deben aguantar más | `.visibilityPriority(.high)` en `ToolbarItem` o `ToolbarItemGroup` |
| Acciones ocasionales que viven siempre en el menú | `ToolbarOverflowMenu { ... }` |

- No pongas `.high` en todo: se pierde la jerarquía. Da a cada acción título e icono.
- `ToolbarSpacer(.fixed)` o `.flexible` agrupan visualmente.
- `.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)` minimiza la barra al hacer scroll; combínalo con `.toolbarMinimizationSafeAreaAdjustment(.disabled, for:)` en contenido a pantalla completa.
- Para versiones anteriores, encapsula la toolbar en un `ViewModifier` con `#available(iOS 27.0, *)` y una barra más sencilla como alternativa.

Ver también `iphone-duo`, `estado-swiftui` y `layout-swiftui`.
