---
name: iphone-duo
description: "Preparar apps para iPhone Duo, el iPhone plegable, con iOS 27.1. Cubre los tres niveles de compatibilidad según el SDK (anterior a iOS 27, iOS 27.0 y 27.1), la pantalla interior con size class regular en ambos ejes, la orientación y UIScreen.main como referencias poco fiables, las áreas seguras asimétricas, ArrangementView (split y overlay), regiones reservadas (reservedRegions .division y .occlusion), barras verticales (axisBehavior, toolbarVerticalEdge, toolbarVerticalCompressionBehavior, toolbarVerticalBehavior), sheets alrededor del pliegue y presentationPlacement. Úsala al adaptar una app SwiftUI o UIKit a iPhone Duo o a pantallas plegables, o al revisar cuadrículas, barras y presentaciones frente al pliegue."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/iphone-duo-compatibilidad-hacia-atras-sdk/
    - https://www.swiftpills.dev/posts/iphone-duo-compatibilidad-apps-ios-27-1/
    - https://www.swiftpills.dev/posts/sheets-y-pliegue-en-iphone-duo/
    - https://www.swiftpills.dev/posts/barras-herramientas-swiftui-iphone-duo/
    - https://www.swiftpills.dev/posts/arrangementview-swiftui-disposiciones-iphone-duo/
    - https://www.swiftpills.dev/posts/posicion-sheets-swiftui-iphone-duo/
    - https://www.swiftpills.dev/posts/colocar-vistas-swiftui-alrededor-pliegue-iphone-duo/
  actualizada: 2026-11-25
---

# iPhone Duo

## El SDK decide cuánto espacio ocupa la app

| Compilada con | Pantalla interior |
|---|---|
| SDK anterior a iOS 27 | Región protegida estrecha con bordes negros |
| SDK de iOS 27.0 | Superficie mayor, barras arriba |
| SDK de iOS 27.1 | De borde a borde, con barras estándar que pueden pasar a vertical |

- El SDK no es el deployment target: puedes compilar con Xcode 27.1 y mantener iOS 17 como mínimo. Las APIs de 27.1 necesitan `#available`.
- Recompilar da más espacio, pero no arregla el diseño. Revisa anchos fijos, decisiones por orientación, `UIScreen.main`, márgenes que se suponen simétricos y barras hechas a mano.

## Reglas generales

- No detectes el dispositivo. La pantalla exterior se comporta como un iPhone; la interior tiene size class **regular en ambos ejes**, así que `NavigationSplitView` muestra columnas sin código específico.
- Las orientaciones declaradas no describen la geometría: usa size classes, geometría o traits.
- No uses `UIScreen.main`. Usa `window?.windowScene?.screen`, el entorno de SwiftUI o la `traitCollection`.
- Las áreas seguras pueden ser **asimétricas**: no calcules el ancho restando dos veces un mismo margen. Los fondos pueden usar `ignoresSafeArea()`; los controles, no.
- Apóyate en `NavigationStack`, `NavigationSplitView`, `TabView`, sheets, menús y alertas: ya se adaptan solos.
- Prueba en Xcode 27.1, en el simulador de Device Hub: abrir, cerrar, girar y plegar **con la pantalla activa** (selección, scroll, sheet abierta, teclado con texto escrito), en Split View, con Dynamic Type grande y con App Resizability.
- Si existe la skill `app-resizability`, úsala para modernizar APIs heredadas.

## ArrangementView (iOS 27.1)

Organiza dos vistas según el espacio y el pliegue. No aporta navegación: envuélvelo en `NavigationStack` y no lo metas dentro de `List` ni de `ScrollView`.

```swift
ArrangementView {
    StepsList()
} secondary: {
    IngredientsList()
        .splitArrangementLayoutRatio(0.35)      // es una preferencia, no un valor exacto
}
.arrangementViewStyle(.split)                   // .automatic equivale a .split
```

- `.split` reparte el espacio en horizontal o vertical según la proporción y se adapta al pliegue. `splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:idealVertical:)`, `splitArrangementLayoutSize` y `splitArrangementFixedLayoutSize` afinan el reparto.
- `.split.axes(.horizontal)` muestra solo la vista principal cuando no puede dividir en ese eje: comprueba que no se pierda funcionalidad.
- `@Environment(\.splitArrangementAxis)` vale `nil` fuera de un split; úsalo para adaptar una subvista.
- `.overlay` pone la principal sobre la secundaria y las separa al plegar. Usa `overlayArrangementEdge(_:)` para elegir el borde y `@Environment(\.overlayArrangementZIndex)` para compactar el panel mientras se superpone.

## Regiones reservadas (iOS 27.1)

Para cuadrículas, controles flotantes o layouts propios que no deben quedar sobre la bisagra:

```swift
.onGeometryChange(for: FoldInfo.self) { proxy in
    let fold = proxy.reservedRegions(kind: .division, options: .includeInactive)
        .first { $0.frame.height > $0.frame.width }          // pliegue vertical
    return FoldInfo(width: proxy.size.width,
                    horizontalRange: fold.map { $0.frame.minX...$0.frame.maxX },
                    isActive: fold?.isActive ?? false)
} action: { foldInfo = $0 }
```

- `.division` es el pliegue; `.occlusion` son la cámara o la Dynamic Island.
- `.includeInactive` detecta el pliegue también con la pantalla abierta, así puedes mantener el mismo número de columnas (mejor par) y solo ensanchar el hueco central al plegar.
- El `frame` ya incluye los márgenes de seguridad y está en coordenadas de la vista.
- Un pliegue horizontal en una lista vertical se esquiva con scroll; uno vertical, no.

## Barras de herramientas verticales

Declara los `ToolbarItem` con ubicaciones semánticas y deja que el sistema los coloque. Da a cada acción **título e icono**.

- `.axisBehavior(.verticalPreferred)` o `.horizontalOnly` en el `ToolbarItem`; por ejemplo, un `Picker` segmentado debe ser `.horizontalOnly`.
- `@Environment(\.toolbarVerticalEdge)` (`leading`, `trailing` o `nil`) adapta una etiqueta propia: `AnyLayout` en HStack o VStack.
- `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` o `.prefersTabBar` decide qué grupo se comprime antes. Por defecto se favorecen las pestañas. Dentro de la barra, usa `visibilityPriority(_:)`.
- `.toolbarVerticalBehavior(.disabled)` dentro del `NavigationStack` de una vista con una sola acción, como una ayuda con un botón Cerrar. Mantén el comportamiento estable dentro de una misma pila.

## Sheets y pliegue

- Las sheets del sistema ya adaptan tamaño, posición y barras: horizontal dentro, vertical fuera. Lee `@Environment(\.dismiss)` dentro de la vista presentada.
- Mantén las acciones lejos del pliegue; el contenido desplazable puede cruzarlo.
- `presentationDetents` controla la altura, no la posición.
- `.presentationPlacement(.trailing)` (iOS 27) se aplica **al contenido de la sheet**. Los valores son `.automatic`, `.center`, `.leading` y `.trailing`, y solo afecta a sheets. Al plegar, `.center`, `.automatic` y `.leading` van a la mitad izquierda y `.trailing` a la derecha. En el borde final, la barra pasa a vertical.
- En UIKit: `sheetPresentationController?.preferredPlacement = .trailing`.

Ver también `layout-swiftui`, `presentaciones-swiftui` y `migracion-ios-27`.
