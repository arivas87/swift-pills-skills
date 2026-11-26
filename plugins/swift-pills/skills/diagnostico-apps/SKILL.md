---
name: diagnostico-apps
description: "Diagnóstico y observabilidad de apps Apple en producción y desarrollo. Cubre Logger y OSLog en lugar de print (subsistema, categoría, niveles, privacidad, interpolación diferida, log stream), MetricKit clásico (MXMetricManagerSubscriber, exit metrics, mxSignpost, Simulate MetricKit Payloads) y el nuevo de iOS 27 (MetricManager, MetricReport, DiagnosticReport), StateReporting en iOS 27 para dar contexto a métricas e Instruments (dominios, estados, metadatos estables y volátiles, @ReportableMetadata) y CrashReportExtension en iOS 27 para analizar un fallo desde otro proceso. Úsala al instrumentar una app, investigar cuelgues, terminaciones o tirones, o al sustituir print por registros útiles."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/tu-app-se-cierra-inesperadamente-y-xcode-organizer-no-te-da-suficiente-informacion-metrickit-es-la-solucion/
    - https://www.swiftpills.dev/posts/statereporting-ios-27-contexto-metrickit-instruments/
    - https://www.swiftpills.dev/posts/crashreportextension-ios-27-diagnostico-fuera-del-proceso/
    - https://www.swiftpills.dev/posts/logger-oslog-swift-sustituir-print/
  actualizada: 2026-11-25
---

# Diagnóstico de apps

## Logger en lugar de print (iOS 14+)

```swift
import OSLog
private let logger = Logger(subsystem: "com.example.Riego", category: "Guardado")

let operationID = UUID().uuidString
logger.notice("Inicio de guardado: \(operationID, privacy: .public)")
logger.debug("Pendientes: \(reminders.count)")
logger.error("Guardado fallido: \(operationID, privacy: .public); \(error.localizedDescription, privacy: .private)")
throw error   // registrar no resuelve: propaga el error
```

| Nivel | Uso | ¿Se conserva? |
|---|---|---|
| `debug` | Detalle de depuración | No se guarda en disco |
| `info` | Contexto | En memoria |
| `notice` | Eventos relevantes | En disco, con límites |
| `error` | Fallos | En disco, con límites |
| `fault` | Supuestos internos incumplidos | En disco, con límites |

- Usa una categoría por área funcional y un id por operación para relacionar los mensajes.
- Pasa el literal interpolado **directamente**: el formateo se aplaza. No calcules antes la descripción ni pongas lógica dentro de la interpolación.
- **Privacidad:** las cadenas y objetos son privados por defecto, los números públicos. Decide valor a valor con `.private` o `.public`; nunca hagas público un dato del usuario para depurar.
- Para consultar: la consola de Xcode filtrada, la app Consola, o `log stream --level debug --predicate 'subsystem == "…"' --style compact` en directo.
- Los logs no son un historial permanente. `print` es solo para la salida de herramientas de línea de comandos.

## MetricKit

**API clásica (iOS 13+):**

- Suscríbete con `MXMetricManagerSubscriber`, registrado mediante `MXMetricManager.shared.add(subscriber)` al arrancar. Recibe `didReceive(_: [MXMetricPayload])` y `[MXDiagnosticPayload]`, más o menos cada 24 horas.
- Las terminaciones están en `payload.applicationExitMetrics?.backgroundExitData`: `cumulativeAbnormalExitCount`, `CPUResourceLimit`, `MemoryPressure` y `MemoryResourceLimit`.
- Métricas propias con `MXMetricManager.makeLogHandle(category:)` y `mxSignpost(.begin/.end, log:name:)`.
- `timeStampBegin` y `timeStampEnd` delimitan el periodo, que puede abarcar varias versiones. Envía `jsonRepresentation()` a tu servidor.
- Para probar: Debug → Simulate MetricKit Payloads en un **dispositivo real**; el simulador no funciona.

**iOS 27 (beta):** la nueva API es `MetricManager(enabledStateReportingDomains: [...])` con `for await report in metricManager.metricReports`. `MetricReport` y `DiagnosticReport` son `Codable`; para agrupar el JSON por dominio, usa `encoder.userInfo[MetricReport.encodingFormatKey] = .byStateReportingDomain`.

## StateReporting (iOS 27, beta)

Añade contexto funcional a MetricKit y a Points of Interest de Instruments. No es analítica ni sustituye a Logger o signposts.

```swift
import StateReporting

@ReportableMetadata struct ExportConfiguration { let codec: String; let preset: String; let isHDR: Bool }  // estable
@ReportableMetadata struct ExportProgress { let progress: Double; let droppedFrames: Int }               // volátil

let reporter = StateReporter.reporter(for: "com.example.editor.export",
                                      stableMetadata: ExportConfiguration.self,
                                      volatileMetadata: ExportProgress.self)
reporter.reportTransition(to: "Encoding", stableMetadata: config, volatileMetadata: progress)
reporter.reportVolatileMetadataUpdate(newProgress)      // misma fase, distinto progreso
reporter.reportTransition(to: nil)                      // limpiar al terminar
```

- **Un estado activo por dominio.** Los procesos simultáneos van en dominios distintos; no inventes estados combinados.
- Un dominio usa **siempre** los mismos tipos de metadatos: cambiarlos provoca un error fatal. Defínelos en un único sitio y guarda el reporter en un objeto de vida larga.
- Los metadatos **estables** son variantes con pocos valores, por las que se agrega. Los **volátiles** describen la situación momentánea. Nunca uses ids de usuario, UUID ni nombres de documento: rompen la agregación y la privacidad. Usa `@ReportableMetadataKey("…")` para fijar claves y `@ReportableMetadataIgnored` para excluir campos.
- **Frecuencia humana:** hay limitación de llamadas. Muestrea el progreso por tramos; no informes en cada frame.
- Solo algunas métricas se segmentan por estado (`stateEntries`): cuelgues, UI lenta, terminaciones y signposts. CPU, memoria, red y lanzamiento quedan en `intervalEntries`.
- Encapsúlalo en una capa propia mientras sea beta.

## CrashReportExtension (iOS 27)

- Usa la plantilla Crash Report Extension, con bundle id derivado de la app (`com.example.App.CrashReporter`). No está disponible en Mac Catalyst ni para apps iOS en Mac.
- `processCrashReport(process: CrashedProcess)` es **síncrono**: no lances una `Task` y vuelvas.
- `process.reason` es un `CrashReason` con `exception` y `codes`, datos Mach en bruto. Guárdalos sin reinterpretar.
- `binaryImages` y `symbolicateAddress(_:)` devuelven un array por las funciones inline, pero **no** dan la traza completa. Para hilos y memoria usa `corpsePort` con APIs Mach (`task_threads`, `mach_vm_read`); el número de puerto no sirve fuera de la extensión.
- Patrón recomendado: escribe un JSON mínimo y versionado en un **App Group** compartido (`.atomic`, nombre con UUID). La app lo envía al relanzarse y lo borra solo cuando ha terminado.
- Mantén la extensión ligera y sin datos personales.
- Sigue archivando los **dSYM** y usando los informes del sistema y MetricKit.

Ver también `rendimiento-swiftui` (Instruments SwiftUI), `lenguaje-swift` (`ContinuousClock`) y `persistencia-swiftdata` (App Groups).
