---
name: texto-y-formato-swiftui
description: "Texto, formato y tipografía en SwiftUI y Foundation. Cubre FormatStyle en Text y TextField (números, moneda, porcentaje, fechas, intervalos, medidas, byteCount, listas), fechas históricas con eras y calendarios, fuentes personalizadas con Dynamic Type (Font.custom relativeTo, @ScaledMetric, dynamicTypeSize), enlaces Markdown y OpenURLAction, AttributedString con Markdown dinámico, textSelection (selección parcial en iOS 27), DataDetector de iOS 26 frente a NSDataDetector, NSTextTable en UIKit con iOS 27 y espacios de no separación. Úsala al mostrar o editar números, fechas y cantidades localizadas, al integrar fuentes propias accesibles, al convertir enlaces en acciones o al detectar entidades en texto libre."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/numeros-que-no-hacen-salto-de-linea-en-swiftui-conoces-este-detalle-tipografico-que-mejora-la-legibilidad/
    - https://www.swiftpills.dev/posts/formatear-valores-swiftui-text-textfield/
    - https://www.swiftpills.dev/posts/enlaces-markdown-swiftui-acciones-openurl/
    - https://www.swiftpills.dev/posts/seleccion-parcial-texto-swiftui-ios-27/
    - https://www.swiftpills.dev/posts/nstexttable-en-swift-tablas-en-nsattributedstring/
    - https://www.swiftpills.dev/posts/datadetector-ios-26-deteccion-semantica-swift/
    - https://www.swiftpills.dev/posts/fechas-historicas-swiftui-eras-calendario/
    - https://www.swiftpills.dev/posts/fuentes-personalizadas-dynamic-type-swiftui/
  actualizada: 2026-11-25
---

# Texto y formato en SwiftUI

## FormatStyle: conserva el tipo hasta el final

No conviertas a `String` antes de tiempo: nada de `"\(value) €"`, `String(format:)` ni un `DateFormatter` por cada `Text`. Foundation aplica el `Locale` del usuario.

```swift
Text(revenue, format: .currency(code: "EUR"))                // 39.284,75 € en es-ES
Text(count, format: .number.notation(.compactName))          // 12 mil
Text(noise, format: .number.precision(.fractionLength(1)))   // redondea solo al mostrar
Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
Text(start..<end, format: .interval.hour().minute())
Text(distance, format: .measurement(width: .abbreviated))    // convierte km/mi según la región
Text(names, format: .list(type: .and))
Text("Ocupará \(size, format: .byteCount(style: .file)) y empezará \(next, format: .relative(presentation: .numeric)).")
```

- `TextField("Precio", value: $rate, format: .currency(code: "EUR"))` enlaza directamente con `Double` o `Int`. El formato debe poder analizarse de vuelta (número, porcentaje, moneda). El tipo del estado manda.
- Para que un número no se parta entre líneas, usa espacios de no separación (`\u{00A0}`) o `AttributedString` con el atributo de mantener unido.

## Fechas históricas

- `Date` es un instante: el año y la era los interpreta `Calendar`. En el calendario gregoriano, `era 0` es antes de nuestra era y `era 1` nuestra era, con años positivos. No existe el año 0, y `-350` no equivale a 350 a. C.
- Construye la fecha con `DateComponents(era:year:month:day:)` y `isValidDate(in:)`, y comprueba que la conversión de vuelta da los mismos componentes. Usa UTC como convención interna.
- Para mostrarla, usa `Date.FormatStyle(locale:calendar:timeZone:).day().month(.wide).year().era(.abbreviated)`. No concatenes "a. C.".
- Ordena por `Date`, no por número de año.
- No inventes precisión: si solo sabes el año, guarda año y era o componentes parciales. La transición gregoriana fija de 1582 no refleja la historia de cada país.

## Fuentes personalizadas con Dynamic Type

- Registra los ficheros en `UIAppFonts` (con extensión) y comprueba que están en Copy Bundle Resources y que la licencia lo permite.
- `Font.custom` necesita el **nombre PostScript**, no el del fichero. Compruébalo con `UIFont.fontNames(forFamilyName:)`. Si el nombre no existe, el sistema cae en silencio a otra fuente.
- Usa siempre `.custom("Literata-Bold", size: 32, relativeTo: .title)`. `custom(_:size:)` escala como `.body`, y `fixedSize:` no escala: solo para glifos decorativos.
- Centraliza los estilos: `enum EditorialTextStyle` y `Font.editorial(.articleTitle)`. Usa las variantes reales de peso (`Literata-SemiBold`) en lugar de `.bold()`.
- `@ScaledMetric(relativeTo: .caption) var iconSize = 14` escala los iconos y paddings ligados al texto.
- Con `dynamicTypeSize.isAccessibilitySize`, pasa de `HStack` a `VStack`. Evita alturas fijas y `minimumScaleFactor`, y no limites `.dynamicTypeSize(...)` en pantallas completas.
- Prueba con `#Preview` y `.dynamicTypeSize(.accessibility5)`, con idiomas largos y con texto en negrita.

## Enlaces Markdown y OpenURLAction

- `Text("Consulta la [guía](https://...)")` funciona con literales. Para cadenas dinámicas, usa `Text(try AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))`.
- Una URL puede expresar una intención interna: `gallery-action://backup/retry`. Intercéptala con:

```swift
.environment(\.openURL, OpenURLAction { url in
    guard url.scheme == "gallery-action" else { return url.scheme == "https" ? .systemAction : .discarded }
    switch HelpAction(url: url) {                 // traduce a un enum cerrado
    case .retryBackup?: showRetryConfirmation = true; return .handled
    case .openStorageSettings?: path.append(.storage); return .handled
    case nil: return .discarded
    }
})
```

- Los resultados posibles son `.handled`, `.discarded`, `.systemAction` y `.systemAction(newURL)`. Sirve también para instrumentar enlaces externos.
- **Seguridad:** el Markdown remoto no es de fiar. Acepta solo una lista cerrada de esquema, host y path, traduce a un enum, delega solo `https`, descarta el resto y pide confirmación en acciones sensibles.
- `openURL` controla los enlaces que salen; `onOpenURL` recibe los que entran.
- `Link` es para una vista que es un destino y `Button` para una acción independiente. Nunca escondas acciones destructivas en un párrafo.

## Selección de texto

- `.textSelection(.enabled)` (iOS 15+) se puede aplicar a un contenedor y se propaga; desactívalo en partes con `.disabled`. En iOS 27 permite seleccionar un fragmento sin cambiar el código.
- `Text` sigue siendo de solo lectura y no expone el rango. Para editar usa `TextEditor` con `TextSelection`; para acciones avanzadas, `UITextView` o TextKit.
- Úsalo en errores, identificadores, documentación y textos legales. Para un único código, mejor un botón de copiar.

## DataDetector (iOS 26)

```swift
import DataDetection
for await match in text.dataDetectorMatches([.calendarEvent, .moneyAmount], options: options) {
    guard let range = match.range else { continue }
    switch match.details { case let .moneyAmount(v): ...; default: break }
}
```

- Es asíncrono y tipado: `range` apunta a `String.Index` y `details` es un enum semántico. Detecta enlaces, correos, teléfonos, eventos, direcciones, importes, medidas, vuelos, envíos y pagos.
- Pide solo los tipos que vayas a usar.
- `DataDetector.Options` (`documentDate`, `documentTimeZone`, `documentLanguageCode`, `documentRegion`) da contexto a expresiones como "mañana".
- Haz el escaneo fuera del actor principal (`@concurrent`), con debounce y cancelación de la tarea anterior.
- `preferredHighlightStyle` es solo una sugerencia.
- **Detectar no es validar:** para validar usa `URL(string:)`, `ParseStrategy` o el servidor.
- Para versiones anteriores, oculta `NSDataDetector` tras un protocolo propio.

## NSTextTable en UIKit (iOS 27)

Sirve para tablas reales dentro de un `NSAttributedString` (informes, facturas, documentos), no como sustituto de `UITableView`.

- `NSTextTable` tiene `numberOfColumns`, `layoutAlgorithm` (`.fixed` o `.automatic`) y `collapsesBorders`.
- Cada celda es un `NSTextTableBlock(table:startingRow:rowSpan:startingColumn:columnSpan:)` asignado a `paragraphStyle.textBlocks = [cell]` de su párrafo. Cada párrafo termina en `\n`.
- Estilo con `setContentWidth(_:type: .percentage)`, `setWidth(_:type:for: .border/.padding)` y, en la versión 27, por lado con `rectEdge:`.
- Muéstralo en un `UITextView`. En SwiftUI, con `UIViewRepresentable`.

Ver también `controles-swiftui` y `lenguaje-swift` (cadenas y Unicode).
