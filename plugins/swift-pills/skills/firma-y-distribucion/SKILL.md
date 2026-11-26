---
name: firma-y-distribucion
description: "Firma, compilación, automatización y distribución de apps Apple. Cubre la firma de código y el aprovisionamiento en iOS (certificados con clave privada, App ID, capabilities frente a entitlements, tipos de perfil, firma automática o manual, diagnóstico con codesign y security cms, CI), distribuir apps de macOS fuera de la Mac App Store (Developer ID, Hardened Runtime, DMG, notarytool, stapler, spctl), pasar de universal a arm64, sustituir On-Demand Resources por Background Assets (AssetPackManager, Apple-Hosted), plugins de Swift Package Manager (CommandPlugin, BuildToolPlugin, permisos) y scripts personalizados de Xcode Cloud (ci_scripts, idempotencia, secretos). Úsala ante errores de firma o perfiles, al publicar o notarizar, al configurar CI o al automatizar el build."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/scripts-personalizados-xcode-cloud/
    - https://www.swiftpills.dev/posts/on-demand-resources-limites-y-migracion-background-assets/
    - https://www.swiftpills.dev/posts/plugins-de-swift-package-manager/
    - https://www.swiftpills.dev/posts/de-universal-a-arm64-cuando-dejar-de-soportar-macs-intel/
    - https://www.swiftpills.dev/posts/firma-de-codigo-y-aprovisionamiento-en-ios/
    - https://www.swiftpills.dev/posts/distribuir-app-macos-fuera-de-la-app-store/
  actualizada: 2026-11-25
---

# Firma y distribución

## Firma y aprovisionamiento

| Pieza | Responde a |
|---|---|
| Certificado **con su clave privada** | Quién firma. Un `.cer` sin clave no sirve: exporta un `.p12`, que es un secreto |
| App ID (`TEAMID.bundle.id`) | Qué app es. Cada extensión, widget o App Clip tiene el suyo |
| Entitlements | Qué privilegios pide el ejecutable |
| Perfil (`.mobileprovision`) | Qué combinación ha autorizado Apple y dónde puede ejecutarse |

- Usa `Apple Development` para depurar y `Apple Distribution` para Ad Hoc, TestFlight y App Store.
- Tipos de perfil: Desarrollo (dispositivos y `get-task-allow`), Ad Hoc (dispositivos) y App Store Connect (sin dispositivos).
- Editar `.entitlements` no concede nada: la capability debe estar en el App ID **y** en el perfil. Cambiar capabilities invalida los perfiles manuales.
- Lo anidado se firma antes que el contenedor, así que un fallo en un `.appex` aparece como fallo de la app.

**Diagnostica antes de tocar nada:**

```bash
security find-identity -v -p codesigning                       # ¿hay identidad con clave privada?
codesign -d --entitlements :- App.app                          # lo que pide el binario
security cms -D -i App.app/embedded.mobileprovision > /tmp/p.plist
/usr/libexec/PlistBuddy -c "Print:Entitlements" /tmp/p.plist   # lo que autoriza el perfil
codesign --verify --deep --strict --verbose=4 App.app
xcodebuild -showBuildSettings ... | grep -E "CODE_SIGN|DEVELOPMENT_TEAM|PROVISIONING_PROFILE"
```

Errores habituales:

- "No signing certificate": falta la clave privada.
- "Profile doesn't include signing certificate": se renovó el certificado y no se regeneró el perfil.
- "doesn't support the capability": falta en el App ID o en el perfil.

**CI:** guarda `.p12`, contraseñas y claves de la API de App Store Connect como secretos, nunca en el repositorio. Usa llaveros temporales. Con firma automática, `-allowProvisioningUpdates` y credenciales. Documenta cuál es la fuente de verdad, local o CI.

## macOS fuera de la Mac App Store

1. Activa **Hardened Runtime**, obligatorio para notarizar, con las mínimas excepciones necesarias (por ejemplo `allow-jit`). Archiva y usa Distribute App → Direct Distribution con `Developer ID Application`. `Developer ID Installer` solo hace falta para `.pkg`.
2. Verifica el `.app` con `codesign --verify --deep --strict`, `codesign --display --verbose=4` y `spctl --assess --type execute`. No uses `codesign --deep --force` como remedio: firma de dentro hacia fuera con los entitlements de cada componente.
3. Crea el DMG: `hdiutil create -format UDRW`, `attach`, `ditto` de la app, enlace a `/Applications`, `detach` y `convert -format UDZO`. Termínalo **antes** de firmar.
4. Firma el DMG con `codesign --force --timestamp --sign "Developer ID Application: …"`; si hay varias identidades, usa su hash SHA-1.
5. Notariza: `xcrun notarytool store-credentials` (en CI, la clave de la API) y `xcrun notarytool submit App.dmg --keychain-profile X --wait`. Si lo rechaza, consulta `notarytool log <id>` y corrige el build; no reenvíes el mismo archivo. `altool` ya no se acepta.
6. Adjunta el ticket con `xcrun stapler staple` y `validate`, y comprueba con `spctl --assess --type open --context context:primary-signature` que aparece `Notarized Developer ID`.
7. Pruébalo descargándolo en un Mac limpio, con cuarentena. Publica el `shasum -a 256`. El artefacto aceptado es **inmutable**. En scripts, usa `set -euo pipefail` y desmonta siempre.

## De universal a arm64

- macOS 26 es el último compatible con Intel. Rosetta seguirá completo en macOS 27 y quedará reducido a partir de macOS 28. Desde junio de 2026, las apps universales con macOS 13+ pueden publicar solo `arm64`.
- Prioridad: si la app es **solo** `x86_64`, añade `arm64` cuanto antes. Si ya es universal, retirar Intel es una decisión de producto: mide el uso real y publica antes una última versión universal de mantenimiento.
- Configura `ARCHS = arm64` en Release. No lo confundas con `ONLY_ACTIVE_ARCH`. **Todos** los binarios deben incluir arm64: extensiones, XPC, ayudantes, frameworks y plug-ins. Elimina las ramas `#if arch(x86_64)` y consulta capacidades reales en lugar de suponerlas por arquitectura.
- Verifica sobre el Archive con `lipo -archs` o `file`, y en App Store Connect → Build Metadata. Prueba una instalación limpia y una actualización desde la versión universal.

## On-Demand Resources → Background Assets

- ODR está obsoleto desde iOS 27: no lo uses en proyectos nuevos. Sus límites se aplican tras el thinning; en iOS 18+ son 4 GB de bundle, 8 GB por pack y 70 GB alojados. Si sigues usándolo, llama siempre a `endAccessingResources()` y usa `setPreservationPriority` con criterio.
- **Managed Background Assets:** los packs se versionan aparte del build, con las políticas `essential`, `prefetch` y `onDemand`. Se crean con `xcrun ba-package template`. Apple-Hosted ofrece 200 GB y 200 packs por app.

```swift
let pack = try await AssetPackManager.shared.assetPack(withID: "FrenchPronunciationB2")
try await AssetPackManager.shared.ensureLocalAvailability(of: pack)
let data = try AssetPackManager.shared.contents(at: "Courses/French/B2/Audio/\(id).m4a")
// Progreso: statusUpdates(forAssetPackWithID:). Borra a mano con remove(assetPackWithID:).
```

- Un pack activo llega a **todas** las versiones instaladas: trata su estructura como una API. Usa rutas compatibles, un esquema versionado o un id nuevo si el cambio es incompatible, y prueba también builds antiguos.

## Plugins de Swift Package Manager

- **CommandPlugin:** acciones manuales (`swift package audit-resources`; lista con `swift package plugin --list`). Informa con `Diagnostics.error` o `remark`. Para escribir en el paquete necesita `permissions: [.writeToPackageDirectory(reason:)]`; en CI, `--allow-writing-to-package-directory`.
- **BuildToolPlugin:** genera código o recursos durante el build. Prefiere `.buildCommand` con `inputFiles` y `outputFiles` declarados (es incremental) a `.prebuildCommand`, que se ejecuta siempre. Escribe en `context.pluginWorkDirectoryURL`.
- Pon la lógica en un `executableTarget` y localízalo con `context.tool(named:)`.
- Se ejecutan en sandbox: revisa los plugins de terceros antes de darles permisos de red o escritura. Usa `XcodeProjectPlugin` bajo `#if canImport` para proyectos de Xcode.

## Scripts de Xcode Cloud

- Van en `ci_scripts/` con tres nombres reservados: `ci_post_clone.sh`, `ci_pre_xcodebuild.sh` y `ci_post_xcodebuild.sh`. Este último se ejecuta **aunque falle** el build.
- Deben ser ejecutables, con shebang explícito (`#!/bin/sh` POSIX o `#!/bin/zsh`) y `set -euo pipefail`.
- Valida las variables (`CI_XCODEBUILD_ACTION`, `CI_BRANCH`, `CI_ARCHIVE_PATH`, `CI_BUILD_NUMBER`, `CI_COMMIT`), que no existen en todas las fases.
- Ordena el script así: condiciones (`exit 0` si no toca actuar), después datos (por ejemplo la versión desde `$CI_ARCHIVE_PATH/Info.plist`) y al final el efecto **idempotente**, como comprobar si el tag ya existe. Comprueba el código HTTP.
- Guarda los secretos en Environment marcados como secretos, nunca en logs ni en URLs y sin `set -x`. Usa tokens de alcance mínimo.
- Los archivos temporales no pasan de un script a otro ni sirven como artefactos.

Ver también `seguridad-privacidad-ios` y `migracion-ios-27`.
