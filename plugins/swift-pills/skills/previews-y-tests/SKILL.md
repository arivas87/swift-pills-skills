---
name: previews-y-tests
description: "Previews de SwiftUI rápidas y reproducibles, y tests con Swift Testing. Cubre servicios mock estáticos inyectados por protocolo, factorías con extension Protocol where Self == Mock, @Previewable, PreviewModifier con makeSharedContext para un ModelContainer de SwiftData en memoria, PreviewTrait con nombre, #Preview(arguments:) en Xcode 27, y las trampas de los tests parametrizados (zip, CaseIterable, lógica en el test). Úsala al escribir o acelerar previews, preparar datos de ejemplo, testear modelos de vista o parametrizar tests con @Test(arguments:)."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/tests-parametrizados-en-swift-testing-las-5-trampas-que-debes-evitar/
    - https://www.swiftpills.dev/posts/acelera-previews-swiftui-servicios-mock-estaticos/
    - https://www.swiftpills.dev/posts/previews-reutilizables-swiftui-previewmodifier/
    - https://www.swiftpills.dev/posts/previsualizar-multiples-estados-swiftui-preview-arguments/
  actualizada: 2026-11-25
---

# Previews y tests

## Previews que no dependen del mundo exterior

Una preview no debe tocar la red, el servidor, credenciales ni persistencia real. Inyecta la fuente de datos por protocolo y usa un mock en memoria. Nada de `if isPreview` dentro de la app.

```swift
protocol DeparturesService: Sendable { func departures() async throws -> [Departure] }

struct PreviewDeparturesService: DeparturesService {
    enum Scenario: Sendable { case success([Departure]), failure }
    let scenario: Scenario
    func departures() async throws -> [Departure] {
        switch scenario { case .success(let d): d; case .failure: throw URLError(.badServerResponse) }
    }
}

extension DeparturesService where Self == PreviewDeparturesService {
    static var previewEmpty: Self { .init(scenario: .success([])) }
    static var previewFailure: Self { .init(scenario: .failure) }
}

#Preview("Error") {
    @Previewable @State var model = DeparturesModel(service: .previewFailure)
    DeparturesView(model: model)            // recorre el mismo load() que en producción
}
```

- Las factorías son propiedades calculadas: cada preview empieza limpia, sin estado global.
- Cubre los casos que rompen el diseño: vacío, error, textos largos, valores límite y localización. Con pocos datos basta.
- Para mostrar la carga, usa una suspensión controlada, nunca una tarea bloqueada.
- Si la preview sigue lenta con el mock, el problema está en `body` o en el renderizado.
- Guarda los mocks en un grupo aparte, un paquete auxiliar o bajo `#if DEBUG`. Nunca uses datos personales ni tokens reales.

## PreviewModifier (iOS 18 y Xcode 16)

Para dependencias compartidas y caras, como un contenedor de SwiftData:

```swift
struct RouteSamples: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: HikingRoute.self, configurations: config)
        container.mainContext.insert(HikingRoute(name: "Bosque del Roble", distance: 6.4))
        try container.mainContext.save()
        return container
    }
    func body(content: Content, context: ModelContainer) -> some View { content.modelContainer(context) }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var routeSamples: Self { .modifier(RouteSamples()) }
}

#Preview("Rutas", traits: .routeSamples) {
    @Previewable @State var shortOnly = false
    NavigationStack { RouteListView(shortRoutesOnly: $shortOnly) }
}
```

- El contexto se comparte por **tipo** de modificador. Para aislar escenarios (vacío frente a con datos), crea tipos distintos.
- `makeSharedContext` puede ser `async throws`, pero está en `@MainActor`: `async` no lleva el trabajo a segundo plano.
- Usa `@Previewable @State` para el estado local de cada preview.

## #Preview(arguments:) (Xcode 27)

```swift
#Preview("Estados del episodio", traits: .sizeThatFitsLayout, arguments: Episode.previewSamples) { episode in
    EpisodeRow(episode: episode)
}
```

- Genera una preview independiente por elemento. `T` no necesita `Identifiable`. Da nombres claros a las variantes con `CustomStringConvertible`.
- Úsalo para **un eje** de estados de negocio. El modo oscuro, Dynamic Type o el dispositivo van en traits o en grupos aparte, para evitar la explosión combinatoria.
- No sustituye a `@Previewable`. Si el proyecto soporta sistemas anteriores, marca la preview con `@available(iOS 26.0, *)`.

## Tests parametrizados en Swift Testing

Las cinco trampas:

1. **Valores opacos en la aserción:** recalcular el resultado esperado con la misma lógica que se prueba.
2. **Lógica en el test:** condicionales para casos especiales.
3. **`allCases` con `zip`:** depende del orden del enum.
4. **`zip` trunca** al array más corto: los casos nuevos se ignoran sin aviso.
5. **Argumentos ocultos** en variables o funciones lejanas.

Mejor así:

```swift
@Test(arguments: [
    (input: "12,5", expected: 12.5),
    (input: "0", expected: 0),
])
func parsesAmounts(input: String, expected: Double) throws {
    #expect(try parseAmount(input) == expected)
}
```

- Escribe los casos literales en `@Test(arguments:)`, con entrada y resultado visibles. En Swift 6.2+, `InlineArray` garantiza longitudes iguales.
- No todo test debe parametrizarse.
- Para modelos de vista, usa un doble del servicio (por ejemplo un actor espía) con `@Test @MainActor`.
- Swift 6.4 permite `Test.cancel()` y usar `#expect` dentro de un `XCTestCase`.

Ver también `estado-swiftui` (MVVM) y `persistencia-swiftdata`.
