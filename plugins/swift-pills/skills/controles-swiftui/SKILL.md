---
name: controles-swiftui
description: "Controles e interacción en SwiftUI. Cubre @FocusState con enum, submitLabel, onSubmit y searchFocused; ToggleStyle personalizados con SF Symbols e isMixed; botones Liquid Glass (.glass, .glassProminent) y buttonBorderShape; Gauge frente a ProgressView y Slider; swipeActions fuera de List con swipeActionsContainer (iOS 27); reordenación con reorderable y reorderContainer (iOS 27); drag & drop con Transferable, draggable, dropDestination y Drag Containers (iOS 27); WebView y WebPage nativos (iOS 26); AsyncImage con caché HTTP, URLRequest y asyncImageURLSession (iOS 27); previsualización de documentos (Quick Look, PDFKit) y listas de macOS con contextMenu(forSelectionType:primaryAction:). Úsala al construir formularios, controles personalizados, colecciones con gestos, contenido web o imágenes remotas."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/gauge-progressview-o-slider-en-swiftui-cual-usar-en-cada-caso/
    - https://www.swiftpills.dev/posts/cuatro-formas-de-previsualizar-documentos-en-swiftui-y-no-conoces-cual-usar-aqui-esta-la-guia-definitiva/
    - https://www.swiftpills.dev/posts/listas-interactivas-en-macos-con-swiftui-seleccion-doble-clic-y-menus-contextuales-unificados/
    - https://www.swiftpills.dev/posts/transferable-el-protocolo-que-revoluciona-copiar-compartir-y-arrastrar-datos-en-swiftui/
    - https://www.swiftpills.dev/posts/asyncimage-cache-http-ios-27/
    - https://www.swiftpills.dev/posts/drag-containers-swiftui-ios-27/
    - https://www.swiftpills.dev/posts/reordenacion-nativa-contenedores-swiftui-ios27/
    - https://www.swiftpills.dev/posts/acciones-deslizamiento-layouts-personalizados-swiftui-ios-27/
    - https://www.swiftpills.dev/posts/cambiar-forma-botones-lg/
    - https://www.swiftpills.dev/posts/webview-nativo-swiftui-ios-26/
    - https://www.swiftpills.dev/posts/togglestyle-personalizados-swiftui-sf-symbols/
    - https://www.swiftpills.dev/posts/controlando-foco-swiftui-focusstate/
  actualizada: 2026-11-25
---

# Controles e interacción en SwiftUI

## Foco con @FocusState

```swift
enum Field: Hashable { case recipient, street, postalCode }
@FocusState private var focusedField: Field?        // nil = ningún campo enfocado

TextField("Destinatario", text: $recipient)
    .focused($focusedField, equals: .recipient)
    .submitLabel(.next)
    .onSubmit { focusedField = .street }
```

- La relación es bidireccional: el toque actualiza el estado y asignar desde código mueve el foco. Con `nil` se cierra el teclado.
- Para validar, lleva el foco al primer campo con error.
- Usa un caso por cada posición; dos campos con el mismo valor son ambiguos.
- Para componentes reutilizables, recibe `FocusState<Field?>.Binding`. El `@FocusState` vive en la vista que decide la navegación.
- `.searchFocused($isSearchFocused)` para `.searchable`. Hay más APIs de foco: `focusable()`, `focusScope`, `defaultFocus`. No lo confundas con `dismiss`.

## Elegir el control

- `Gauge` para un valor medido de solo lectura, con estilos `.linearCapacity` y `.accessoryCircular`.
- `ProgressView` para el avance de una tarea.
- `Slider` para un valor que el usuario ajusta.

## ToggleStyle personalizados

```swift
struct SymbolToggleStyle: ToggleStyle {
    var onSymbol = "checkmark.circle.fill", offSymbol = "circle", mixedSymbol = "minus.circle.fill"
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer()
                Image(systemName: configuration.isMixed ? mixedSymbol : configuration.isOn ? onSymbol : offSymbol)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
extension ToggleStyle where Self == SymbolToggleStyle { static var symbol: Self { .init() } }
```

- `Toggle("Todo", sources: $items, isOn: \.isEnabled)` produce `isMixed` cuando los valores no coinciden.
- Para decorar sin reimplementar, usa `Toggle(configuration).padding().background(...)`.
- `.toggleStyle(.symbol)` en un contenedor se propaga a sus hijos.

## Botones Liquid Glass

- `.buttonStyle(.glass)` o `.glassProminent` (iOS 26). Cambia la forma con `.buttonBorderShape(.circle)`, `.capsule` o `.roundedRectangle(radius:)`, **no** con `clipShape`: este recorta después y rompe los efectos y estados.
- Usa círculo para iconos sueltos y cápsula para botones con texto. Se puede aplicar a un contenedor y sobrescribir en un hijo.
- En versiones anteriores, envuelve el estilo en un `ViewModifier` con `#available(iOS 26, *)` y `.bordered` como alternativa.

## swipeActions fuera de List (iOS 27)

```swift
ScrollView {
    LazyVStack { ForEach(items) { card($0).swipeActions(edge: .trailing, allowsFullSwipe: false) { ... } } }
}
.swipeActionsContainer()      // en el ScrollView; sin esto, el gesto falla en silencio
```

- La variante `swipeActions { } onPresentationChanged: { isPresented in }` informa de un estado transitorio. Protege la escritura: `else if activeID == item.id { activeID = nil }`.
- Las acciones destructivas llevan `role: .destructive` y `allowsFullSwipe: false` o confirmación.
- Ofrece siempre una alternativa visible o un menú contextual, sobre todo en versiones anteriores, donde el gesto no existe.

## Reordenación (iOS 27)

```swift
LazyVStack { ForEach(projects) { Text($0.name) }.reorderable() }
    .reorderContainer(for: Project.self) { difference in projects.apply(difference: difference) }
```

## Drag & drop

- **Transferable:** usa `CodableRepresentation(contentType: .miTipo)` con un `UTType(exportedAs:)` declarado en el proyecto, `DataRepresentation`, `FileRepresentation` para ficheros grandes y `ProxyRepresentation(exporting: \.titulo)` como alternativa de texto. `String`, `Data`, `URL`, `Image` y `AttributedString` ya son `Transferable`.
- Básico: `.draggable(nota)` y `.dropDestination(for: Nota.self) { items, location in ...; return true }`.
- **Drag Containers (iOS 27):** la celda solo expone el id y el contenedor resuelve el payload.

```swift
TicketCard(ticket: t).draggable(containerItemID: t.id)
// contenedor:
.dragContainer(for: Ticket.self) { ids in let s = Set(ids); return tickets.filter { s.contains($0.id) && $0.canMove } }
.dragContainerSelection(selectedIDs)          // si arrastras uno seleccionado, se mueven todos los seleccionados
.dragConfiguration(DragConfiguration(allowMove: true))
```

- Devolver `[]` cancela el arrastre.
- `itemID: \.code` para tipos que no son `Identifiable`.
- Usa `@Namespace` con `in:` y `containerNamespace:` si hay varios contenedores del mismo tipo.
- `DragConfiguration` declara operaciones, no muta el modelo.

## WebView nativo (iOS 26)

- Necesita `import SwiftUI` e `import WebKit` en el mismo archivo (cross-import overlay). Lo mínimo es `WebView(url:)`.
- Con estado: `@State private var page = WebPage()`, `WebView(page)` y `.task { page.load(URLRequest(url: url)) }`. `WebPage` es `@Observable` y expone `title`, `isLoading`, `estimatedProgress`, `url`, `backForwardList` y `hasOnlySecureContent`.
- `load` devuelve una secuencia de eventos de navegación (`for try await`). `try await page.callJavaScript("return ...")` es async: trata el contenido como externo.
- Modificadores: `.webViewContentBackground(.hidden)`, `.webViewMagnificationGestures`, `.webViewLinkPreviews`, `.webViewTextSelection` y `.findNavigator(isPresented:)`.
- Para versiones anteriores, aísla la vista moderna con `@available` y mantén un `UIViewRepresentable` de `WKWebView`.

## AsyncImage y caché (iOS 27)

- `AsyncImage` usa la caché HTTP estándar: depende de las cabeceras del servidor (`Cache-Control: public, max-age=31536000, immutable`, `ETag`).
- Versiona las URLs (`avatar-v17.png` o `?v=17`). Nunca uses un `?cacheBust` aleatorio.
- `AsyncImage(request:)` con `cachePolicy` (`.returnCacheDataElseLoad` para recursos inmutables) y `timeoutInterval`. Evita `.reloadIgnoringLocalCacheData` como arreglo general.
- `.asyncImageURLSession(Sessions.catalog)` con una sesión **estable** (estática) y su `URLCache`. Nunca crees una `URLSession` en `body`.
- Para galerías grandes, prefetch, downsampling o prioridades, usa una pipeline o librería de imágenes dedicada.

## Documentos y macOS

- Quick Look (`.quickLookPreview($url)`, con `import QuickLook`) para lo más simple. PDFKit (`PDFView` en un representable) para PDFs avanzados. `WebView` o `WKWebView` para incrustar. `UIDocumentInteractionController` para las acciones del sistema.
- Listas de macOS: `List(items, selection: $selectionID)` con `.contextMenu(forSelectionType: Item.ID.self) { selection in ... } primaryAction: { selection in open(...) }`. El doble clic y Return van en `primaryAction`; no uses `onTapGesture(count: 2)`. `.contentShape(.rect)` hace pulsable toda la fila.

Ver también `texto-y-formato-swiftui`, `animaciones-swiftui` y `presentaciones-swiftui`.
