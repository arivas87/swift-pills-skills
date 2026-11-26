---
name: animaciones-swiftui
description: "Animaciones y respuesta sensorial en SwiftUI. Cubre .animation(_:value:) frente a withAnimation y su completion, curvas (easing, timingCurve, smooth, snappy, bouncy, spring) y modificadores (delay, speed, repeat), PhaseAnimator con fases y trigger, KeyframeAnimator, TimelineView y sus schedules (everyMinute, periodic, animation, propios) con cadence, efectos de SF Symbols (symbolEffect, replace, byLayer, sombra interior) y sensoryFeedback para hápticos. También accesibilidad con accessibilityReduceMotion. Úsala al animar cambios de estado, crear secuencias, mostrar relojes o cuentas atrás, animar iconos o añadir hápticos."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/sombra-interior-en-sf-symbols-el-efecto-que-desconocias-para-tus-iconos-en-swiftui/
    - https://www.swiftpills.dev/posts/sigues-usando-sf-symbols-estaticos-cuando-podrias-darles-vida-con-animaciones-nativas/
    - https://www.swiftpills.dev/posts/animaciones-basicas-swiftui/
    - https://www.swiftpills.dev/posts/timelineview-en-swiftui/
    - https://www.swiftpills.dev/posts/timing-animaciones-swiftui/
    - https://www.swiftpills.dev/posts/animaciones-por-fases-en-swiftui/
    - https://www.swiftpills.dev/posts/respuesta-haptica-swiftui-sensoryfeedback/
  actualizada: 2026-11-25
---

# Animaciones en SwiftUI

## Implícita o explícita

- `.animation(.easeInOut(duration: 0.3), value: expanded)` anima todo lo que dependa de ese valor. Úsala para componentes locales.
- `withAnimation(.spring(duration: 0.5)) { ... }` anima una transacción concreta y agrupa varios cambios. Escala mejor en pantallas complejas.
- `withAnimation(...) { ... } completion: { siguientePaso() }` sustituye a los temporizadores y retrasos artificiales.
- Mantén duraciones de 0.2 a 0.4 s y anima solo lo que ayuda a entender el cambio.

## Elegir la curva

| Curva | Úsala para |
|---|---|
| `.linear` | Velocidad constante (rotación continua, progreso) |
| `.easeOut` | Contenido que aparece |
| `.easeIn` | Contenido que desaparece |
| `.easeInOut` | Movimiento entre dos estados |
| `.smooth` | Sin rebote; estabilidad |
| `.snappy` | Rebote leve; respuesta rápida |
| `.bouncy(duration:extraBounce:)` | Llamar la atención, con moderación |
| `.spring(response:dampingFraction:)` | Gestos interactivos |
| `.timingCurve(.bezier(startControlPoint:endControlPoint:), duration:)` | Curva a medida |

- Desde iOS 17, la animación por defecto es un spring.
- Modificadores: `.delay()`, `.speed()`, `.repeatCount(_:autoreverses:)` y `.repeatForever(autoreverses:)`. Para un escalonado, usa `.smooth.delay(Double(index) * 0.08)`.
- `CustomAnimation` (iOS 17) define la interpolación a mano y devuelve `nil` al terminar.

## PhaseAnimator (iOS 17)

Úsalo para secuencias de estados discretos; cada fase es la apariencia **completa** de la vista.

```swift
private enum CartFeedbackPhase: CaseIterable, Equatable {
    case resting, pressed, lifted, settled
    var scale: CGFloat { switch self { case .pressed: 0.88; case .lifted: 1.18; default: 1 } }
    var animation: Animation {
        switch self {
        case .resting: .smooth(duration: 0.2)
        case .pressed: .easeOut(duration: 0.12)
        case .lifted: .spring(duration: 0.28, bounce: 0.35)
        case .settled: .spring(duration: 0.35, bounce: 0.18)
        }
    }
}

Button { addItem(); addCount += 1 } label: { Label("Añadir", systemImage: "cart.badge.plus") }
    .phaseAnimator(CartFeedbackPhase.allCases, trigger: addCount) { view, phase in
        view.scaleEffect(phase.scale)
    } animation: { phase in phase.animation }      // la curva con la que se llega a esa fase
```

- Sin `trigger`, la secuencia se repite mientras la vista está en pantalla. Para pararla, retira la vista de la jerarquía.
- El `trigger` debe ser un contador de eventos, no el estado de negocio. No lo envuelvas en `withAnimation`.
- Las fases son visuales y locales: decláralas junto al componente. La colección no puede estar vacía.
- Si cada propiedad necesita su propia línea de tiempo, usa `KeyframeAnimator`.

## TimelineView

Úsalo cuando la **representación** depende del tiempo: relojes, cuentas atrás, progreso entre dos fechas o efectos continuos. No almacenes `now` en un `@State` con un `Timer`.

```swift
TimelineView(.periodic(from: .now, by: 1)) { context in
    Text(remaining(from: context.date, to: deadline))
        .monospacedDigit()
        .contentTransition(.numericText())
}
```

- `.everyMinute` para textos relativos u horas sin segundos.
- `.periodic(from:by:)` para un intervalo fijo.
- `.animation(minimumInterval: 1/30, paused: !isRunning)` para efectos continuos calculados a partir del tiempo. Pausa cuando no se vea.
- Un `TimelineSchedule` propio (`entries(from:mode:)`) para instantes concretos.
- `context.cadence` puede bajar, por ejemplo en el Watch con la muñeca bajada. Simplifica el detalle si no es `.live`.
- El closure debe ser ligero. No lo uses para refrescar datos ni lógica de negocio: para eso están `.task`, `BackgroundTasks` o un servicio.

## SF Symbols

- `.symbolEffect(.bounce, value: trigger)` (discreto) o `.symbolEffect(.pulse)` (continuo), con efectos `pulse`, `bounce`, `wiggle`, `rotate` y `breathe`. Admiten `.repeat()`, `.speed()` y `.byLayer`.
- `.contentTransition(.symbolEffect(.replace))` para pasar de play a pause o de corazón vacío a lleno.
- Sombra interior (iOS 16): `.foregroundStyle(.orange.gradient.shadow(.inner(radius: 3)))` con `.symbolVariant(.circle.fill)` da un aspecto hundido o neumórfico.

## Hápticos con sensoryFeedback (iOS 17)

```swift
.sensoryFeedback(.success, trigger: finished)
.sensoryFeedback(trigger: isValid) { _, newValue in newValue ? .success : nil }   // condicional
```

- Tipos: `.success`, `.warning`, `.error`, `.selection`, `.increase`, `.decrease`, `.impact`, `.start` y `.stop`.
- SwiftUI se adapta al hardware disponible.
- Resérvalos para acciones relevantes, como complemento de lo visual.

## Accesibilidad

Con `@Environment(\.accessibilityReduceMotion)`, sustituye las animaciones continuas por una versión estática. El movimiento refuerza el significado, nunca lo transmite solo: mantén un texto o etiqueta que diga el estado.

Ver también `rendimiento-swiftui` (`geometryGroup`) y `controles-swiftui`.
