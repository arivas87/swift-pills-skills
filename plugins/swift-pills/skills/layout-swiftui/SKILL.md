---
name: layout-swiftui
description: "Layout adaptativo en SwiftUI para ventanas redimensionables. Cubre por qué no decidir por dispositivo, idiom, orientación o size class; ViewThatFits; onGeometryChange con umbrales semánticos; AnyLayout; containerRelativeFrame (count, span y spacing); fixedSize y el tamaño ideal; layoutPriority en HStack, VStack, ZStack, Layout (LayoutSubview.priority) y ViewThatFits; guías de alineación y AlignmentID personalizados; esquinas concéntricas (ConcentricRectangle frente a ContainerRelativeShape); márgenes del sistema con ContentMarginGuide (iOS 27.1); detectar el final de un ScrollView con onScrollGeometryChange; y ContentBuilder frente a ViewBuilder en Xcode 27. Úsala al construir interfaces que se adapten a iPad, iPhone Mirroring o apps de iPhone redimensionables, o al sustituir GeometryReader, UIScreen.main.bounds, offsets y radios mágicos."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/esquinas-concentricas-en-swiftui/
    - https://www.swiftpills.dev/posts/de-size-classes-al-espacio-disponible-en-swiftui/
    - https://www.swiftpills.dev/posts/interfaces-adaptativas-swiftui-containerrelativeframe/
    - https://www.swiftpills.dev/posts/ongeometrychange-swiftui-responder-cambios-geometria/
    - https://www.swiftpills.dev/posts/guias-de-alineacion-en-swiftui/
    - https://www.swiftpills.dev/posts/detectar-final-scroll-swiftui/
    - https://www.swiftpills.dev/posts/margenes-sistema-swiftui-contentmarginguide/
    - https://www.swiftpills.dev/posts/fixedsize-swiftui-tamano-ideal-layout/
    - https://www.swiftpills.dev/posts/contentbuilder-swiftui-un-solo-builder-para-distintos-contenidos/
    - https://www.swiftpills.dev/posts/contentbuilder-swiftui-xcode-27/
    - https://www.swiftpills.dev/posts/layout-priority-contenedores-swiftui/
  actualizada: 2026-11-27
---

# Layout en SwiftUI

## Decide por el espacio, no por el dispositivo

Con iOS 27, las apps de iPhone se pueden redimensionar en iPad y en iPhone Mirroring manteniendo el idiom `.phone` y una size class compacta. No uses estos datos para el layout:

- `UIDevice.current.userInterfaceIdiom == .pad`
- `UIScreen.main.bounds.width`
- `interfaceOrientation.isLandscape`

Aplica estas opciones por orden, de la que menos suposiciones hace a la que más:

1. Contenedores del sistema (`NavigationSplitView`) para la navegación.
2. Límites del motor de layout: `frame(minWidth:idealWidth:maxWidth:)`, `Grid`, stacks y prioridades.
3. `ViewThatFits(in: .horizontal) { completo; compacto }` para variantes del mismo componente.
4. Geometría local con `onGeometryChange` cuando haya un cambio estructural con un umbral propio.
5. `horizontalSizeClass` o el idiom solo para decisiones semánticas de grano grueso.

No fuerces `.environment(\.horizontalSizeClass, .regular)`. En UIKit, usa `view.bounds` en `viewDidLayoutSubviews` o `UIWindowScene.effectiveGeometry`.

Prueba en una ventana estrecha y otra muy ancha con idiom de iPhone, en ventanas de iPad de varios tamaños, en Mirroring, con Dynamic Type grande y dentro de columnas y hojas. Las previews pueden fijar el tamaño con `.frame(width:height:)`.

## onGeometryChange (iOS 16+)

Convierte la geometría en el **dato mínimo**: un `Bool` o un enum `Equatable & Sendable`. `action` solo se ejecuta cuando ese valor cambia.

```swift
.onGeometryChange(for: DashboardLayoutMode.self) { proxy in
    proxy.size.width >= 720 ? .wide : .narrow        // función pura, barata (@Sendable)
} action: { layoutMode = $0 }

let layout = layoutMode == .wide
    ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
    : AnyLayout(VStackLayout(spacing: 20))           // AnyLayout conserva el estado de los hijos
```

- El umbral es del componente: no es una constante global.
- Evita ciclos: el estado que cambias no debe alterar la geometría que mides. Mide un contenedor cuyo tamaño viene de fuera.
- Prefiere `onGeometryChange` a `GeometryReader` con `PreferenceKey` cuando solo quieras medir.

## containerRelativeFrame (iOS 17+)

Dimensiona en relación con el contenedor compatible más cercano (ventana o pantalla, columna de split, `NavigationStack`, pestaña, `ScrollView`, `List`), no con el padre inmediato. Ya descuenta el área segura y `contentMargins`.

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 12) {                         // el mismo spacing en el contenedor
        ForEach(photos) { PhotoCard(photo: $0)
            .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 12) }
    }
}
.contentMargins(.horizontal, 20)
.scrollTargetBehavior(.paging)                        // con .containerRelativeFrame(.horizontal) para páginas

.containerRelativeFrame(.vertical) { length, _ in length * 0.6 }
```

Sustituye a `.frame(width: UIScreen.main.bounds.width - 40)`. No es lo mismo que `.frame(maxWidth: .infinity)`, que acepta la propuesta del padre.

## fixedSize y el tamaño ideal

- `fixedSize()` no fija un número: propone `nil` y la vista adopta su **tamaño ideal**, aunque desborde. El orden de los modificadores importa.
- `Text("...").fixedSize(horizontal: false, vertical: true)` evita truncar en vertical respetando el ancho.
- El tamaño ideal de las formas y los colores es 10×10. Defínelo con `.frame(idealWidth:idealHeight:)` antes de `fixedSize()`.
- Puede dejar sin espacio a sus hermanos. Úsalo con cuidado con Dynamic Type y en ventanas estrechas.

## layoutPriority depende del contenedor

La prioridad por defecto es `0` y solo se compara entre hermanos directos del mismo contenedor. Cada contenedor la interpreta a su manera:

- **`HStack` / `VStack`**: reparte el eje principal. Reserva primero el mínimo de las vistas de menor prioridad (y el `spacing`) y ofrece el resto al grupo de mayor prioridad; lo que este no usa pasa al siguiente grupo. Sirve para decidir qué se trunca antes, no para garantizar que algo no se trunque: si el espacio no llega para la vista prioritaria, también se corta.
- **`ZStack`**: las vistas del grupo de mayor prioridad deciden el tamaño del stack, que luego se propone al resto. Sin prioridades, todas miden, y una forma o un color flexibles se expanden a toda la propuesta.
- **`Layout` personalizado**: solo influye si lees `subview.priority` en `sizeThatFits` y `placeSubviews`.
- **`ViewThatFits`**: la ignora. Elige la primera alternativa, en orden de declaración, cuyo tamaño ideal cabe en los ejes indicados. Para cambiar cuándo salta la variante compacta, reordena o ajusta las alternativas.

```swift
HStack(spacing: 6) {
    Text(product.name).lineLimit(1)              // se trunca primero
    Spacer(minLength: 0)
    VStack(alignment: .trailing) {               // la prioridad va en el hijo directo del HStack
        Text(product.price, format: .currency(code: "EUR"))
        Text("IVA incl.").font(.caption2)
    }
    .layoutPriority(1)
}

ZStack {
    RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.2))   // se adapta
    Text("Oferta").padding(8).layoutPriority(1)                    // marca el tamaño
}
```

- Si la prioridad no surte efecto, comprueba que está en el hijo directo del contenedor que reparte el espacio, no en una vista anidada.
- Para que un fondo siga el tamaño de su contenido, `.background(_:in:)` es más directo que un `ZStack` con prioridades. Añadir `layoutPriority` no cambia el orden de dibujado.
- Si lo esencial no cabe con Dynamic Type grande, ofrece una variante vertical con `ViewThatFits` en lugar de subir prioridades.

## Guías de alineación

- Una guía es un punto de la vista que el contenedor hace coincidir entre los hijos, no un desplazamiento. Prefiérela a `offset`, que no participa en el layout y no escala con Dynamic Type.
- Para texto con fuentes distintas, usa `HStack(alignment: .firstTextBaseline)`.
- Para cambiar el punto que comunica una vista, usa `.alignmentGuide(.firstTextBaseline) { d in d.height * 0.72 }`. Deriva el valor de `ViewDimensions` (`d[.top]`, `d.height`), nunca de una constante. Al aumentar el valor, la vista sube.
- Para alinear con un descendiente de otro contenedor, crea una guía personalizada; se propaga por la jerarquía:

```swift
private struct SongTitleAlignment: AlignmentID {
    static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.firstTextBaseline] }
}
extension VerticalAlignment { static let songTitle = VerticalAlignment(SongTitleAlignment.self) }
// HStack(alignment: .songTitle) { ...; VStack { Text(title).alignmentGuide(.songTitle) { $0[.firstTextBaseline] } } }
```

## Esquinas concéntricas

- Declara la forma del contenedor con `.containerShape(.rect(cornerRadius: 30))`; esto no recorta, así que añade `clipShape` si hace falta. Después, en las capas interiores:
  - `.containerRelative` (`ContainerRelativeShape`) da una copia con margen de la forma completa.
  - `ConcentricRectangle` (iOS 26+) calcula esquina por esquina: `.concentric`, `.concentric(minimum: 12)` o `.fixed(22)`. Por defecto es individual: una esquina alejada del borde puede quedar cuadrada. Usa `isUniform: true` o los inicializadores `uniformTopCorners:` y `uniformBottomCorners:` para mantener la simetría.
- Los contenedores compatibles con `RoundedRectangularShape` son `Rectangle`, `RoundedRectangle`, `UnevenRoundedRectangle`, `Capsule` y `Circle`. Con otros, se usa el comportamiento relativo.
- Evita radios mágicos como `28 - 8 = 20`. Para versiones anteriores, usa `#available` con `.containerRelative` como alternativa.

## Márgenes del sistema (iOS 27.1)

- `.contentMargins(for: .container, edges: .horizontal)` aplica al contenido los márgenes que decide el sistema, que pueden ser distintos en cada lado, por ejemplo en iPhone Duo. No uses `.padding(.horizontal, 16)` para alinear con el título.
- No lo confundas con `.contentMargins(.horizontal, 24, for: .scrollContent)` (iOS 17), que fija una distancia concreta.
- Para leer los valores en un carrusel, usa `proxy.contentMargins(for: .container, edges: .horizontal)` y pásalos a `.contentMargins(..., for: .scrollContent)`. Los valores son locales al lector y no incluyen el área segura: no la sumes otra vez.
- Para versiones anteriores, encapsúlalo en un `ViewModifier` con `#available` y `padding` como alternativa.

## Final de un ScrollView (iOS 18+)

```swift
.onScrollGeometryChange(for: Bool.self) { g in
    let bottom = max(-g.contentInsets.top,
                     g.contentSize.height + g.contentInsets.bottom - g.containerSize.height)
    return g.contentOffset.y >= bottom - 1
} action: { _, isAtBottom in self.isAtBottom = isAtBottom }
```

- Devuelve una condición, no el offset.
- No cambies la altura del contenido observado según el resultado: colócalo fuera.
- Llegar al límite no es lo mismo que ver el último elemento: para eso usa `onScrollVisibilityChange(threshold:)`.
- Para paginar, controla aparte las peticiones simultáneas y si quedan páginas.

## ContentBuilder (Xcode 27)

- `ContentBuilder` es un alias de `ViewBuilder` y unifica los builders de vistas, toolbars y comandos. El tipo de retorno (`some View`, `some ToolbarContent`) sigue decidiendo qué es válido.
- Mejora el tiempo de comprobación de tipos al compilar con Xcode 27, sea cual sea el deployment target.
- No hace falta migrar los `@ViewBuilder`. Usa `@ContentBuilder` en APIs nuevas que reciben contenido en sentido amplio.
- Si aparece "unable to type-check this expression in reasonable time", sigue extrayendo subvistas.

Ver también `iphone-duo`, `presentaciones-swiftui` y `rendimiento-swiftui`.
