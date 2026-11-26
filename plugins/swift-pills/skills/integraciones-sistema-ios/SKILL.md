---
name: integraciones-sistema-ios
description: "Integraciones de una app con el sistema en iOS y watchOS. Cubre Universal Links (Associated Domains, AASA con components, exclusiones y substitutionVariables, CDN de Apple, mode=developer, validación y diagnóstico por capas, parser de URLs con onOpenURL), búsqueda desde Siri con App Intents (system.searchInApp e iOS 27), notificaciones con respuesta de texto (UNTextInputNotificationAction), Now Playing en iOS 27 con MediaSessionRepresentable, Language Discovery (Locale.preferredLocales), ampliar el gesto de volver atrás en UIKit y peculiaridades de watchOS (WCSession, HKWorkoutSession, TimelineSchedule, recuperación de entrenamientos). Úsala al abrir la app desde enlaces o Siri, integrar controles multimedia o notificaciones interactivas, o al desarrollar para Apple Watch."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/tu-app-sigue-obligando-a-los-usuarios-a-elegir-idioma-manualmente-ios-26-language-discovery-cambia-las-reglas-del-juego/
    - https://www.swiftpills.dev/posts/probando-universal-links-en-desarrollo-y-la-cdn-de-apple-te-frena-el-modo-alternativo-es-tu-salvavidas/
    - https://www.swiftpills.dev/posts/universal-links-a-escala/
    - https://www.swiftpills.dev/posts/deslizar-desde-cualquier-punto-de-la-pantalla-para-volver-atras-en-uikit-una-experiencia-nativa-mejorada/
    - https://www.swiftpills.dev/posts/sabias-que-puedes-permitir-a-los-usuarios-responder-directamente-desde-una-notificacion-sin-abrir-tu-app/
    - https://www.swiftpills.dev/posts/desarrollar-para-watchos-no-es-ios-en-miniatura-son-mundos-diferentes/
    - https://www.swiftpills.dev/posts/busqueda-en-app-desde-siri-app-intents/
    - https://www.swiftpills.dev/posts/now-playing-ios-27-sesiones-multimedia/
  actualizada: 2026-11-25
---

# Integraciones con el sistema

## Universal Links

Son un contrato entre el **binario** (el entitlement `applinks:dominio`), el **servidor** (el AASA) y el **código** (el parser que decide la pantalla).

- `applinks:*.museo.example` **no** incluye `museo.example`: declara ambos.
- Publica el AASA en `https://dominio/.well-known/apple-app-site-association`: sin extensión, con HTTPS y **sin redirecciones**.
- En `components`, las reglas se evalúan **en orden** y gana la primera que coincide: pon las exclusiones (`"exclude": true`) antes que las reglas generales. Usa `"/"` para el path, `"?"` para la query y `"#"` para el fragmento; tienen que cumplirse todos los componentes declarados. Las `substitutionVariables` y `$(lang)` o `$(region)` evitan duplicar rutas localizadas. Usa `percentEncoded` de forma explícita.
- Que el JSON sea válido no significa que el AASA lo sea. Valídalo en CI con un esquema y una matriz `opens_app` / `opens_web`, sin olvidar las URLs que deben quedarse en la web.
- **CDN de Apple** (iOS 14+): el dispositivo lee `https://app-site-association.cdn-apple.com/a/v1/<dominio>`, que tarda horas en propagarse y no se puede invalidar. Vigila que el origen y la CDN coincidan, comparándolos de forma estructural.
- **En desarrollo:** `applinks:staging.dominio?mode=developer`, firmando con un perfil de desarrollo y activando Associated Domains Development en Ajustes → Desarrollador. Existen también `mode=managed` (MDM) y `developer+managed`. Nunca los dejes en producción. Para staging hacen falta un dominio y HTTPS reales.
- **Parser en Swift:** valida el esquema `https`, una lista de hosts permitidos y los segmentos y parámetros con `URLComponents`, y conviértelo en un enum de destinos. En `.onOpenURL`, navega solo si se reconoce el destino.
- **Diagnostica por capas:** entitlements firmados, origen (certificado, HTTP, cabeceras, redirecciones), contenido y orden de las reglas, CDN, Universal Links Diagnostics y logs de `swcd`, la app y el contexto. Prueba desde Mail o Notas, no escribiendo la URL en Safari. iOS recuerda si el usuario eligió abrir el enlace en la web.

## Búsqueda desde Siri (App Intents, iOS 27)

```swift
@available(iOS 27.0, *)
@AppIntent(schema: .system.searchInApp)
struct SearchToolsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]
    var criteria: StringSearchCriteria
    @MainActor func perform() async throws -> some IntentResult {
        ToolNavigation.shared.showSearch(for: criteria.term)   // el mismo estado que usa la UI
        return .result()
    }
}
```

- La consulta que llega desde Siri debe pasar por **la misma lógica** de búsqueda que la del teclado.
- Ya se ejecuta en primer plano: no añadas `openAppWhenRun`. Con varias ventanas, decide qué escena recibe la búsqueda.
- Si hay onboarding o login, conserva la consulta hasta poder mostrarla. Cancela las búsquedas remotas anteriores.
- `IndexedEntity` e `IntentValueQuery` son integraciones complementarias. Prueba primero en Atajos y después con Siri en un dispositivo real.
- Si existen, usa las skills `app-intents-specialist` y `app-intents-whats-new-27`.

## Notificaciones con respuesta de texto (iOS 10+)

- Define una `UNTextInputNotificationAction(identifier:title:options:textInputButtonTitle:textInputPlaceholder:)` dentro de una `UNNotificationCategory` y regístrala al arrancar con `setNotificationCategories`. Asigna `content.categoryIdentifier` a la notificación.
- En `userNotificationCenter(_:didReceive:withCompletionHandler:)`, haz el cast a `UNTextInputNotificationResponse` para leer `userText` y llama **siempre** al `completionHandler`. Si hay trabajo de red, usa tareas en segundo plano.

## Now Playing (iOS 27)

- Adopta `@MainActor @Observable final class LessonSession: @MainActor MediaSessionRepresentable` con `id`, `content` (`GenericContent`, `MusicContent`, `MovieContent` o `BookContent`, con ids estables), `playbackSnapshot` y `commands` (`.play { }`, `.pause { }`), que deben invocar **las mismas acciones** que la UI.
- `MediaPlaybackSnapshot(state:defaultPlaybackRate:elapsedTime:timestamp:)` usa como `timestamp` el **instante real de la medición**. Actualiza al pausar, saltar, cambiar de velocidad o quedarse esperando datos, no cada segundo.
- Configura `AVAudioSession` con `.playback`, crea `MediaSession(model)` y llama a `requestToBecomeApplicationPrimary()`. Guarda la sesión en una propiedad. Para seguir sonando con el dispositivo bloqueado, activa Background Modes → Audio.
- **No mezcles** esta API con `MPNowPlayingInfoCenter` ni `MPRemoteCommandCenter`: el resultado es indefinido. Elige según la versión del sistema. Las sesiones remotas usan `RemoteMediaSessionExtension`.

## Language Discovery (iOS 26)

`Locale.preferredLocales` devuelve los idiomas reales del usuario, deducidos en el dispositivo, con metadatos de dirección del texto, numeración, calendario, moneda y región. No obligues al usuario a elegir en listas ni mantengas tablas culturales escritas a mano.

## Volver atrás desde toda la pantalla (UIKit)

Asigna `interactivePopGestureRecognizer?.delegate = self` en un `UINavigationController` propio, con `gestureRecognizerShouldBegin` que devuelva `viewControllers.count > 1` para no hacer pop del controlador raíz.

## watchOS

- Las versiones de iPhone y Watch desalineadas rompen la instalación, HealthKit y `WCSession`.
- Sincronización: `WCSession` (`sendMessage` puede despertar la app del iPhone; `transferFile` no funciona en el simulador), CloudKit o el almacén clave-valor de iCloud. App Groups no funciona entre iPhone y Watch.
- Cambiar permisos en el iPhone mata la app del Watch: diseña la reconexión y la recuperación de estado.
- **Batería** con `HKWorkoutSession`: refresca menos cuando `isLuminanceReduced` está activo y usa `TimelineSchedule` (1 Hz con la muñeca levantada, cada 10-20 s atenuado) en lugar de redibujar con cada métrica.
- Las fugas se acumulan porque la app casi nunca se reinicia. Un `TabView` anidado provoca fugas.
- Si el reloj se reinicia, `handleActiveWorkoutRecovery` no se llama: comprueba `HKHealthStore().recoverActiveWorkoutSession` al arrancar y guarda tú las métricas propias.
- Usa SwiftUI con watchOS 9 como mínimo. Los crash logs son escasos: registra localmente y envíalos al iPhone por `WCSession`.

Ver también `texto-y-formato-swiftui` (`openURL` frente a `onOpenURL`), `ciclo-de-vida-swiftui` (`.backgroundTask`) y `animaciones-swiftui` (`TimelineView`).
