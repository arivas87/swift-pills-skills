---
name: migracion-ios-27
description: "Preparar una app para el SDK de iOS 27 y Xcode 27. Cubre los tres requisitos obligatorios (UIScene lifecycle, pantalla de lanzamiento con el error ITMS-90870 y Liquid Glass sin UIDesignRequiresCompatibility), la diferencia entre SDK y deployment target, backporting de APIs nuevas de SwiftUI con extensiones de View y #available, el nuevo formato de proyecto project.xcproj en JSON (Xcode 27.2) y la exportación de las Agent Skills de Xcode 27 para asistentes de IA. Úsala al subir el SDK de una app existente, al planificar la migración de una app UIKit antigua o al adoptar APIs nuevas sin subir la versión mínima."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/ios-27-sdk-requerimientos/
    - https://www.swiftpills.dev/posts/agent-skills-xcode-27/
    - https://www.swiftpills.dev/posts/como-utilizar-nuevas-apis-swiftui-versiones-anteriores-ios/
    - https://www.swiftpills.dev/posts/de-pbxproj-a-xcproj-proyectos-xcode-json/
  actualizada: 2026-11-25
---

# Migración a iOS 27 y Xcode 27

## Requisitos obligatorios del SDK de iOS 27

Revísalos en este orden:

1. **UIScene lifecycle.** Sin él, la app termina al arrancar. Declara el manifiesto de escenas en el Info.plist y un `UIWindowSceneDelegate` que cree la `UIWindow` en `scene(_:willConnectTo:options:)`. Las apps SwiftUI con `App` ya cumplen. Deja de decidir el layout por idiom u orientación (ver `ciclo-de-vida-swiftui` y `layout-swiftui`).
2. **Pantalla de lanzamiento.** App Store Connect rechaza la subida con `ITMS-90870: Missing launch screen` si el Info.plist del **producto compilado** no tiene `UILaunchStoryboardName`, `UILaunchStoryboards`, `UILaunchScreen` o `UILaunchScreens`.
3. **Liquid Glass.** `UIDesignRequiresCompatibility` se ignora. Revisa barras de navegación y de pestañas, cabeceras translúcidas, fondos propios, `UIAppearance` y dependencias de áreas seguras concretas.

En iPhone Duo, compilar con el SDK 27.1 cambia cuánto espacio ocupa la app (ver `iphone-duo`).

## SDK frente a deployment target

- El SDK decide qué APIs conoce el compilador; el deployment target, desde qué iOS se instala la app. Puedes compilar con Xcode 27 y mantener iOS 15.
- `#available` comprueba en ejecución, pero no permite usar APIs que el SDK no conoce.
- Algunas mejoras dependen solo del compilador (Xcode 27): `@State` como macro, `ContentBuilder`. Otras, del sistema en el que se ejecuta.

## Backporting con extensiones de View

Concentra las diferencias de versión en un único modificador:

```swift
extension View {
    func emptyState(isEmpty: Bool, title: LocalizedStringKey, systemImage: String, message: LocalizedStringKey) -> some View {
        overlay {
            if isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
                } else {
                    VStack(spacing: 12) { Image(systemName: systemImage).font(.largeTitle); Text(title).font(.headline); Text(message).foregroundStyle(.secondary) }
                }
            }
        }
    }
}
```

- Usa en la firma solo tipos que existan desde la versión mínima. Crea un enum propio y conviértelo dentro de la rama.
- Una mejora visual puede devolver `self` en versiones antiguas; una funcionalidad necesaria debe tener una alternativa real.
- Para retirarlo después, marca el modificador con `@available(iOS, deprecated: 17.0, message: "Usa ContentUnavailableView")`.
- Para tipos nuevos (por ejemplo `WebPage`), aísla la vista moderna en un tipo `@available` propio.

## project.xcproj en JSON (Xcode 27.2)

- `MiApp.xcodeproj` sigue siendo el paquete; por dentro, `project.xcproj` (JSON) sustituye a `project.pbxproj`. Los ajustes llevan condiciones del tipo `"SWIFT_OPTIMIZATION_LEVEL[config=Debug]": "-Onone"`.
- Se convierte en Project Document → Project Format → JSON. Compatible con Xcode 27 y posteriores; los proyectos nuevos ya lo usan.
- Haz la conversión en un **commit aparte**, desde una copia limpia y con la misma versión de Xcode que la CI. Compila, ejecuta las pruebas y archiva. Busca scripts que mencionen `project.pbxproj` y revisa las herramientas (XcodeProj de Tuist lo soporta de forma experimental).
- `apple/xcode-project-format` ofrece `XCSchema.Project(jsonRepresentation:)` para auditorías propias, como comprobar que existan los targets esperados. Que el JSON sea válido no garantiza que la configuración sea correcta: revisa los cambios que hagan los agentes.

## Agent Skills de Xcode 27

```bash
xcrun xcodebuild -exportAgentSkills --output-dir ./AgentSkills
```

- Incluye `swiftui-specialist`, `swiftui-whats-new-27`, `uikit-app-modernization`, `audit-xcode-security-settings`, `test-modernizer`, `device-interaction` y `c-bounds-safety`.
- Si falla, comprueba `xcode-select -p` y elige Xcode 27 en Settings → Locations → Command Line Tools.
