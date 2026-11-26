---
name: persistencia-swiftdata
description: "Persistencia con SwiftData, CloudKit y ficheros compartidos. Cubre ModelContainer, ModelContext, @Model y @Query; @Query dinámico inicializado en el init de una subvista; #Predicate frente a filter y #Index; cuándo añadir un ViewModel sobre SwiftData; qué hacer cuando falla save() (rollback o un contexto por operación); sincronizar con un servidor propio con historial, HistoryObserver y tokens (iOS 27); CloudKit (bases privada, compartida y pública, CKRecord, zonas, CKSyncEngine, esquema de producción, encryptedValues) frente a SwiftData o Core Data con CloudKit; y guardar archivos desde extensiones con App Groups, Documents y bookmarks. Úsala al diseñar modelos y consultas, al sincronizar datos o al compartir ficheros entre app y extensión."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/swiftdata-necesita-mvvm-o-es-sobre-ingenieria-hay-un-camino-intermedio/
    - https://www.swiftpills.dev/posts/swiftdata-en-2025-de-codigo-caotico-a-arquitectura-maestra/
    - https://www.swiftpills.dev/posts/crees-que-query-en-swiftdata-es-estatico-te-sorprendera-lo-dinamico-que-puede-ser/
    - https://www.swiftpills.dev/posts/sincronizar-swiftdata-backend-historyobserver/
    - https://www.swiftpills.dev/posts/cloudkit-que-es-y-como-funciona-el-backend-de-apple/
    - https://www.swiftpills.dev/posts/swiftdata-rollback-tras-fallar-save/
    - https://www.swiftpills.dev/posts/guardar-archivos-extension-ios-documents-bookmarks/
  actualizada: 2026-11-25
---

# Persistencia con SwiftData y CloudKit

## Base de SwiftData

- `ModelContainer` gestiona el esquema y el almacén; `ModelContext` gestiona las lecturas y escrituras.
- `@Model` genera `PersistentModel`, `Observable`, `Hashable` e `Identifiable`. `@Query` lee de forma reactiva desde el contexto del entorno.
- **Arquitectura:** `@Query` ya cubre la lectura. Añade un modelo de vista solo para escrituras con reglas de negocio, validación o tests, que reciba el `modelContext`. No dupliques la lectura en otra capa. Si hay migraciones complejas o necesidad de portabilidad, plantéate abstraer tras protocolos.
- Filtra con `#Predicate`, que se ejecuta en la base de datos, y no con `.filter` en memoria. Usa `#Index` (iOS 18) en las propiedades que más se filtran u ordenan. Los enums propios no funcionan directamente en predicados ni en `SortDescriptor`.

## @Query dinámico

`@Query` no puede leer `@State` de la propia vista al inicializarse. Pon el estado (filtro, búsqueda, orden) en una vista contenedora y crea la consulta en el `init` de una subvista:

```swift
struct UserList: View {
    @Query private var users: [User]
    init(search: String, sort: [SortDescriptor<User>]) {
        _users = Query(filter: #Predicate { search.isEmpty || $0.name.localizedStandardContains(search) }, sort: sort)
    }
    var body: some View { List(users) { Text($0.name) } }
}
```

Cuando cambian los parámetros, SwiftUI recrea la subvista y con ella la consulta.

## Cuando falla save()

Un `save()` que lanza un error **no limpia** los cambios pendientes. El siguiente guardado, sea manual o el autosave del `mainContext`, puede confirmar lo que diste por fallido.

```swift
extension ModelContext {
    func saveOrRollback() throws {
        guard hasChanges else { return }
        do { try save() } catch { rollback(); throw error }
    }
}
```

- `rollback()` afecta a **todo** el contexto, incluidas las ediciones de otras pantallas que lo compartan.
- Alternativa: un contexto por operación (`ModelContext(container)` con `autosaveEnabled = false`). El formulario mantiene los valores en `@State` y, si falla, el contexto se descarta. Para editar, pasa el `PersistentIdentifier`, que es `Sendable`.
- Para probarlo: inyecta el error, haz después un guardado correcto y comprueba con otro contexto que no quedó nada a medias. Con borrados en cascada, prueba `processPendingChanges()` antes de `rollback()`.

## Sincronizar con un servidor propio (historial e HistoryObserver)

- **Identidad estable:** usa `@Attribute(.unique, .preserveValueOnDeletion) var syncID: UUID`. Nunca envíes `PersistentIdentifier` al servidor. Conserva en los borrados solo el id, sin datos sensibles.
- **Autor:** `context.author = "app"` en el contexto que realmente escribe la UI y `"server"` en el de importación. Filtra **siempre** por autor, también en la primera consulta, para no reenviar lo que llegó del servidor.
- **HistoryObserver** (iOS 27, beta): `HistoryObserver(observedModels:authors:modelContainer:isolation:)` solo avisa a través de `eventCounter`. Observa con `withContinuousObservation` y guarda **los dos** tokens. Haz además una pasada al arrancar, al volver al primer plano y al recuperar la red.
- **Leer:** `HistoryDescriptor<DefaultHistoryTransaction>` con `#Predicate { $0.token > token && $0.author == author }` y `context.fetchHistory`. Junta varias ediciones en el estado más reciente. Para los borrados, lee `deletion.tombstone[\.syncID] as? UUID`; si falta, no avances el token.
- **Enviar:** usa DTOs `Codable` (no `@Model`) y una clave de idempotencia. **Avanza el token solo después de que el servidor confirme.** Guarda el token por cuenta y por almacén. Ante `historyTokenExpired`, reconcilia todo.
- Serializa las pasadas en un actor global para que no corran a la vez. Los conflictos los resuelve el servidor: usa versiones o `ETag` en lugar de `modifiedAt`, que depende del reloj del dispositivo. Reintenta con backoff exponencial.

## CloudKit

| Base | Contenido | Notas |
|---|---|---|
| `privateCloudDatabase` | Datos del usuario | Consume su iCloud; requiere cuenta (`accountStatus()`) |
| `sharedCloudDatabase` | Lo que otros comparten con él | Mediante `CKShare`, con permisos por participante |
| `publicCloudDatabase` | Datos comunes de la app | Se lee sin cuenta; nunca para datos privados |

- `CKRecord` es una colección de pares clave-valor por tipo. CloudKit **no** es una base de datos local: si trabajas con él directamente, mantén tu propia copia local y sincroniza.
- Usa `CKRecordZone` para cambios incrementales y para compartir. `CKSyncEngine` gestiona los cambios pendientes, las suscripciones y los reintentos. Tú persistes su estado serializado y usas `fetchChanges` y `sendChanges` cuando necesites sincronizar a mano. No sirve para la base pública.
- **Elegir nivel:**
  - SwiftData con CloudKit: `ModelConfiguration(cloudKitDatabase: .private("iCloud.id"))`. Sincroniza datos privados, sin Sharing. Necesita la capability de iCloud con CloudKit y Background Modes → Remote notifications. No admite `@Attribute(.unique)` ni relaciones no opcionales.
  - Core Data con `NSPersistentCloudKitContainer`: añade Sharing.
  - CloudKit directo con `CKSyncEngine`: máximo control.
- **Esquema:** en desarrollo es flexible. Despliégalo a producción desde CloudKit Console y prueba contra producción antes de TestFlight. En producción **no se pueden borrar** tipos ni campos: trátalo como una API.
- Usa `record.encryptedValues["campo"]` para cifrar. Esos campos no se pueden indexar, y un campo existente no se puede convertir en cifrado.
- La sincronización no es instantánea. Gestiona errores de cuota y de límite de peticiones.

## Archivos desde extensiones

- Una extensión no ve el `Documents` de la app. Comparte un contenedor con **App Groups**: `containerURL(forSecurityApplicationGroupIdentifier:)`. Usa nombres únicos y escrituras `.atomic`, y coordina con `NSFileCoordinator` o `UIDocument` si ambos procesos modifican lo mismo.
- Para que algo aparezca en Archivos, la app necesita `UIFileSharingEnabled` y `LSSupportsOpeningDocumentsInPlace`, que solo exponen su `Documents`. Una opción es mover lo pendiente del grupo a `Documents` al abrir la app.
- **Bookmarks:** solo garantizan acceso a carpetas elegidas por el usuario (selector de documentos, `.minimalBookmark`). Resuelve con `bookmarkDataIsStale`, `startAccessingSecurityScopedResource()` y su `stop` en `defer`, y termina la operación dentro del bloque. Compartir un bookmark del `Documents` privado con una extensión no es una garantía documentada: pruébalo antes de depender de ello.
- Si algo falla, deja la importación pendiente en el grupo. Nunca informes de un guardado que no se ha completado.

Ver también `concurrencia-swift`, `estado-swiftui` (`withContinuousObservation`) y `previews-y-tests` (contenedor en memoria).
