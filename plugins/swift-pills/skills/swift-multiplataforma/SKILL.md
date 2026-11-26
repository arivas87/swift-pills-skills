---
name: swift-multiplataforma
description: "Swift fuera de las apps de Apple. Cubre Swift en Android (SDK oficial, swift-java con jextract y wrap-java, @available(Android 33, *)), Swift en Windows (runtime con -static-stdlib, side-by-side, Experimental Swift SDK, librerías estáticas frente a de importación, WinGet), Embedded Swift con las mejoras de Swift 6.4 (any, throws sin tipo, metatipos, PerformanceHints), WebAssembly con Elementary (HTML tipado en el servidor) y ElementaryUI (UI reactiva en el navegador), Swift Configuration 1.0 (ConfigReader y proveedores) y swift-subprocess para herramientas de línea de comandos. Úsala para compartir lógica Swift con Android, Windows, servidor o web, escribir firmware o herramientas CLI, o gestionar configuración en servicios Swift."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/swift-subprocess-el-futuro-del-scripting-en-swift-o-solo-una-ilusion/
    - https://www.swiftpills.dev/posts/gestionar-configuracion-en-swift-sigue-siendo-un-dolor-de-cabeza-con-codigo-disperso-y-acoplado-swift-configuration-1-0-cambia-las-reglas/
    - https://www.swiftpills.dev/posts/swift-en-android-es-oficial/
    - https://www.swiftpills.dev/posts/swift-en-windows-un-ano-de-refinamiento/
    - https://www.swiftpills.dev/posts/elementary-y-elementaryui-swift-del-servidor-al-navegador/
    - https://www.swiftpills.dev/posts/embedded-swift-mejoras-swift-6-4/
    - https://www.swiftpills.dev/posts/swift-cierra-2025-como-un-lenguaje-verdaderamente-universal-del-servidor-al-microcontrolador/
  actualizada: 2026-11-25
---

# Swift multiplataforma

**Patrón común:** la lógica de negocio, los modelos, el parseo y los algoritmos van en un paquete Swift compartido; la interfaz es nativa en cada plataforma. Reserva `#if os(...)` para la integración con la plataforma. Swift Testing funciona en todas ellas.

## Android

- El SDK oficial está disponible desde las previews de Swift 6.3. Compila a nativo con LLVM e incluye Foundation y Dispatch.
- Interoperabilidad con **swift-java**: `jextract` genera bindings para llamar a Swift desde Java (con el modo JNI admite versiones antiguas de Android) y `wrap-java` permite usar APIs de Java desde Swift.
- Usa `@available(Android 33, *)` e `if #available(Android 33, *)` para APIs recientes, con compatibilidad desde API 28.

## Windows

- No hay estabilidad de ABI: liga la app a una versión concreta del runtime. **No dependas del orden de `Path`**, porque con varias toolchains puede cargarse el runtime equivocado.
- **`-static-stdlib`** (Experimental Swift SDK) para herramientas de un solo binario y para CI: versión fija, LTO y eliminación de código muerto. A cambio, el binario es mayor y una corrección de seguridad obliga a recompilar. Solo afecta a las librerías de Swift.
- **Side-by-side** (manifiestos SxS) para apps que comparten DLL.
- `libswiftCore.lib` es la librería estática y `swiftCore.lib` la de importación de la DLL: compilador, autoenlace y linker deben coincidir.
- Instalación: `winget install --id Swift.Toolchain` junto con el SDK de Windows y las herramientas de C++ de Visual Studio. Para editar, la extensión oficial de VS Code.
- Win32: `-enable-experimental-feature ImportMacroAliases` permite llamar a `CreateFile` sin el sufijo `W`. La toolchain genera SBOM.

## Embedded Swift (experimental)

Es un subconjunto de Swift para microcontroladores, firmware y bare metal: sin reflexión ni metadatos dinámicos y con los genéricos especializados en compilación.

- **Swift 6.4** añade existenciales `any` también para valores, `throws` sin tipo, metatipos completos (`any Command.Type`), `Double(String)` y task groups con errores.
- Pasar un existencial a una API genérica sigue sin estar permitido.
- `any Error` puede reservar memoria en el heap: en firmware sin asignaciones dinámicas, usa `throws(MiError)`.
- Activa los diagnósticos `PerformanceHints` para ver costes ocultos como llamadas indirectas o metadatos.
- Swift 6.3 trajo `InlineArray`, `Span` y mejor interoperabilidad con C.

## Web: Elementary y ElementaryUI

- **Elementary:** HTML tipado con un result builder, sin Foundation ni reflexión. Implementa `HTMLDocument` con `head` y `body`. Puede renderizar en streaming (`AsyncForEach`). Tiene integraciones para Vapor y Hummingbird. No incluye estado reactivo; para interactividad desde el servidor, combínalo con HTMX.
- **ElementaryUI:** Swift compilado a WebAssembly en el navegador. Usa `@View`, `@State`, `@Binding`, `@Reactive` (equivalente a `@Observable`, compatible con Embedded), `@Environment`, `.onClick`, `task`, `withAnimation` y se monta con `Application(View()).mount(in: "#app")`.
- **Es un framework web, no SwiftUI:** un `div` es un `div` y el diseño lo hace CSS. Siguen importando la semántica HTML y la accesibilidad.
- Usa el target `-embedded` del SDK de Wasm para que el binario sea pequeño, con sus limitaciones (las claves de `ForEach` deben poder convertirse a texto).
- Requisitos: Swift 6.3+, un SDK de Wasm de la misma versión, Node 22+ y la plantilla Vite (`npx degit elementary-swift/starter-vite`).
- Todavía no hay hidratación: usa islas (página generada con Elementary y aplicaciones ElementaryUI montadas en contenedores). Es un proyecto temprano.

## Swift Configuration 1.0

```swift
let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(),                                   // mayor prioridad
    try await FileProvider<JSONSnapshot>(filePath: "/etc/config.json")
])
let timeout = config.int(forKey: "http.timeout", default: 60)
```

- Separa dónde se lee la configuración de dónde viene: las librerías reciben un `ConfigReader` sin imponer el origen.
- Proveedores: variables de entorno, ficheros JSON o YAML, argumentos de línea de comandos y `ConfigProvider` propios.
- Admite recarga en caliente, observadores, espacios de nombres, registro de accesos y **ocultación de secretos** en los logs.

## swift-subprocess

- Sustituye a `Process` con async/await: `run(.name("git"), arguments: [...])`. Es multiplataforma y requiere Swift 6.1.
- Necesita un paquete de SwiftPM con un target ejecutable, así que no es scripting ligero. Úsalo en herramientas CLI y automatización compleja; para tareas triviales, Bash sigue siendo más simple.

Ver también `lenguaje-swift` (`throws` tipados, `anyAppleOS`), `concurrencia-swift` y `firma-y-distribucion` (plugins de SwiftPM).
