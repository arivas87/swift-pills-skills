---
name: foundation-models
description: "IA en apps Apple con el framework Foundation Models. Cubre LanguageModelSession con el modelo del sistema, la ventana de contexto (contextSize, tokenCount, exceededContextWindowSize), @Generable y @Guide, streamResponse con PartiallyGenerated, prewarm, el instrumento de Instruments, el protocolo LanguageModel de iOS 27 (Private Cloud Compute, Core AI, MLX, Claude con ClaudeForFoundationModels, Gemini con Firebase AI Logic, ChatCompletionsLanguageModel), DynamicProfile para enrutar entre modelo local y remoto, FoundationModelsUtilities (droppingCompletedToolCalls, rollingWindow, summarizeHistory, Skills), métricas de uso, qué abre Apple como código abierto y Media Intelligence (FaceGroupAnalyzer, VideoAnalyzer). Úsala al integrar modelos de lenguaje en una app Swift, decidir entre IA local y en la nube, gestionar el contexto o analizar fotos y vídeos en el dispositivo."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/sabias-que-el-modelo-de-foundation-models-tiene-un-limite-de-contexto-que-puede-romper-tu-app/
    - https://www.swiftpills.dev/posts/integras-modelos-de-ia-en-tus-apps-de-ios-26-pero-no-sabes-si-su-rendimiento-es-optimo/
    - https://www.swiftpills.dev/posts/claude-apple-foundation-models/
    - https://www.swiftpills.dev/posts/foundation-models-codigo-abierto-que-abre-apple/
    - https://www.swiftpills.dev/posts/foundation-models-utilities-en-swift/
    - https://www.swiftpills.dev/posts/media-intelligence-ios-27/
    - https://www.swiftpills.dev/posts/ia-hibrida-en-swift-con-foundation-models-y-gemini/
  actualizada: 2026-11-25
---

# Foundation Models

Muchas de estas APIs (iOS 27) están en beta: encapsúlalas tras protocolos propios y vuelve a probar con cada Xcode.

## Base

```swift
import FoundationModels
let session = LanguageModelSession(model: SystemLanguageModel.default)
let response = try await session.respond(to: "Resume estas notas en tres puntos: \(notes)")

@Generable struct IncidentSummary {
    @Guide(description: "Título breve") var title: String
    @Guide(description: "low, medium, high o critical") var severity: String
    var nextSteps: [String]
}
let summary = try await session.respond(to: prompt, generating: IncidentSummary.self).content
```

- Comprueba la disponibilidad (`model.isAvailable`): requiere un dispositivo con Apple Intelligence. Ten siempre una experiencia alternativa.
- **Streaming:** `for try await partial in session.streamResponse(to:generating:)` entrega **instantáneas acumulativas**: reemplaza el contenido, no lo concatenes. Los campos de `PartiallyGenerated` son opcionales y la UI no debe forzar desempaquetados.
- `session.prewarm(promptPrefix:)` reduce la latencia cuando ya conoces el prompt.
- Para medir, usa Instruments → instrumento Foundation Models en un dispositivo real; en el simulador los tokens salen a 0. Para herramientas lentas, cachea los resultados.

## Ventana de contexto

- La sesión tiene estado: cada `respond` envía todo el historial. Instrucciones, esquema `@Generable`, herramientas, resultados de herramientas y respuestas **consumen contexto**. Al superarlo se produce `exceededContextWindowSize` o `contextSizeExceeded`.
- La ventana fue de 4096 tokens en iOS 26; en iOS 27 se muestran 8192. **No uses una constante:** consulta `model.contextSize` y `try await model.tokenCount(for:)`, y deja una reserva para la respuesta.
- Estrategias: abrir una sesión nueva, resumir y usar el resumen como instrucciones, ventana deslizante y validar la longitud antes de enviar. Los adaptadores pueden consumir mucho contexto.
- El estado importante (ids, decisiones) se guarda en tipos de dominio persistentes, no en la transcripción.

## Varios modelos con el protocolo LanguageModel (iOS 27)

Una sola `LanguageModelSession` puede funcionar con `SystemLanguageModel`, `PrivateCloudComputeLanguageModel` (más contexto y razonamiento, sin claves), `CoreAILanguageModel`, `MLXLanguageModel` o adaptadores de proveedores.

- **Claude** (`ClaudeForFoundationModels`): `ClaudeLanguageModel(name:auth:baseURL:serverTools:)`. `.apiKey` es **solo para desarrollo**; en producción usa `.proxied(headers: ["Authorization": "Bearer \(userToken)"])` contra tu backend, que guarda la clave, valida al usuario y aplica cuotas. Las herramientas de servidor (`.webSearch(maxUses:)`, `.codeExecution`) solo deben recibir datos que puedan salir del dispositivo.
- **Gemini** (Firebase AI Logic, en preview): `FirebaseAI.firebaseAI(backend: .googleAI()).geminiLanguageModel(name:)` con **App Check** activado y App Attest en producción.
- **Servidores compatibles con Chat Completions:** `ChatCompletionsLanguageModel(name:url:additionalHeaders:supportsGuidedGeneration:urlSessionConfiguration:)` de FoundationModelsUtilities. Usa `supportsGuidedGeneration: false` si el backend no admite `response_format`. Compatible en el formato no significa compatible en las capacidades.
- **Nunca** incluyas claves de proveedores en el binario.

## Enrutar entre local y nube

- Centraliza la decisión en una política comprobable, por ejemplo en un actor que devuelve `.onDevice` o `.cloud`. Ten en cuenta la sensibilidad de los datos (siempre local), el permiso del usuario para la nube, `tokenCount` frente a `contextSize`, la disponibilidad, la conectividad, el coste y el tipo de tarea.
- **Elige antes de generar**, no con un `catch` que reintenta en la nube: gastas recursos y podrías enviar fuera contenido que el modelo local rechazó por seguridad. Clasifica los errores: el exceso de contexto puede justificar la nube si el usuario la ha autorizado; un rechazo del modelo, nunca.
- `LanguageModelSession.DynamicProfile` concentra instrucciones, herramientas, `.model(...)`, `.temperature()` y `.reasoningLevel()` por ruta. Su `body` se evalúa antes de cada petición. No uses `try!` al construir modelos dentro del perfil.
- **Privacidad:** la misma API no implica la misma privacidad. Muestra cuándo los datos salen del dispositivo, pide consentimiento y ofrece una alternativa.
- Traduce los errores (`LanguageModelError`, `ClaudeError`) a mensajes accionables, sin mostrar errores de bajo nivel.
- **Uso:** `response.usage.input.totalTokenCount`, `cachedTokenCount`, `output.totalTokenCount` y `reasoningTokenCount`. Registra agregados sin contenido privado y evalúa calidad, latencia y coste con casos reales.

## FoundationModelsUtilities (experimental, Apache 2.0)

Paquete `https://github.com/apple/foundation-models-utilities` (iOS 27, Swift 6.2). Fija la versión.

```swift
Profile { Instructions("..."); ReadDeviceManualTool() }
    .summarizeHistory(entryThreshold: 16, model: summarizer)   // se aplica el último
    .rollingWindow(entries: 24)
    .droppingCompletedToolCalls()                               // se aplica el primero
```

- Los modificadores se aplican **de fuera hacia dentro**. `droppingCompletedToolCalls` pierde datos de herramientas a los que el usuario podría volver a referirse. Las entradas no son tokens. Un resumen puede omitir detalles.
- **Skills:** `Skills(activations: runtime.skillActivations) { Skill(name:description:prompt:) ; Skill(name:description:instructions:allowsDeactivation:) }`.
  - Con `prompt`, el contenido llega como resultado de una herramienta y se conserva la caché: úsalo para material de referencia.
  - Con `instructions`, se añade a las instrucciones con más prioridad, pero invalida la caché del prefijo.
  - La activación la decide el modelo: **nunca** la uses como control de seguridad o autorización.
- Las skills de la carpeta `skills/` del repositorio son para agentes de programación, no para la app.

## Código abierto

Apple abre el **framework** (sesiones, `@Generable`, herramientas, protocolo `LanguageModel` y soporte para Linux), no los pesos del modelo de Apple Intelligence. Una API uniforme no significa capacidades, costes ni privacidad uniformes.

## Media Intelligence (iOS 27, beta)

- **`FaceGroupAnalyzer(workingDirectory:)`:** índice persistente en Application Support que pertenece al framework; no lo toques. Recibe `MediaIntelligenceImageAsset(id:kind:)` con ids **estables**. `insertOrUpdateAssets` devuelve una secuencia asíncrona. Con el estado `.stale`, llama a `update()` para reagrupar. Consultas: `allFacesByEntityID`, `fetchFaces(for:)` e `identifyFaces(in:)`, esta última sin persistir.
- Un grupo **no es una identidad verificada**: permite corregir, unir, dividir y nombrar. Guarda los nombres en tu propio almacén.
- **`VideoAnalyzer.shared.analyze(video, for: KeyFrameAnalysisRequest(), HighlightAnalysisRequest())`** devuelve fotogramas clave y momentos destacados. Las miniaturas y la exportación se hacen con AVFoundation. Para OCR, poses o análisis de un solo fotograma, usa Vision.
- Ejecuta fuera del `MainActor` (`@concurrent`), en lotes idempotentes y con el progreso persistido. Pruébalo en un dispositivo físico.
- Explica al usuario por qué analizas personas y ofrece borrado: `deleteAssets`, `deleteAllAssets` y `FaceGroupAnalyzer.purge(workingDirectory:)`.

Ver también `concurrencia-swift`, `seguridad-privacidad-ios` (BFF, App Attest) y `estado-swiftui`.
