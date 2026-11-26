---
name: seguridad-privacidad-ios
description: "Seguridad y privacidad en apps iOS. Cubre dónde no guardar API keys (BFF o proxy, tokens de corta duración), Keychain con un wrapper tipado (kSecAttrAccessible, ThisDeviceOnly, access groups, SecAccessControl con userPresence), App Attest y Secure Enclave (attestKey, assertions, validación en el servidor), TLS en URLSession sin debilitar la validación (errores de certificado, SAN, cadena intermedia, OpenSSL, NSPinnedDomains), Privacy Manifests (PrivacyInfo.xcprivacy, Required Reason APIs, SDKs, informe de privacidad), App Tracking Transparency en la UE con iOS 27.2 y Trust Insights en iOS 27 contra la ingeniería social. Úsala al guardar secretos, proteger peticiones, diagnosticar errores TLS, preparar el envío a App Store o pedir permiso de seguimiento."
metadata:
  fuentes:
    - https://www.swiftpills.dev/posts/guardas-las-api-keys-directamente-en-tu-app-de-swiftui-es-el-error-que-te-costara-caro/
    - https://www.swiftpills.dev/posts/keychain-ios-almacenamiento-seguro/
    - https://www.swiftpills.dev/posts/privacy-manifests-en-ios/
    - https://www.swiftpills.dev/posts/app-tracking-transparency-ue-ios-27-2/
    - https://www.swiftpills.dev/posts/trust-insights-ios-27-ingenieria-social/
    - https://www.swiftpills.dev/posts/certificados-tls-ios-validacion-y-diagnostico/
    - https://www.swiftpills.dev/posts/app-attest-claves-secure-enclave-ios/
  actualizada: 2026-11-25
---

# Seguridad y privacidad en iOS

## Secretos y API keys

- Ningún secreto en el cliente es seguro: `.plist`, `.xcconfig` y el binario se pueden extraer. Los secretos críticos van en el servidor, con un **BFF** o proxy que llama a los servicios externos.
- Usa tokens de acceso de corta duración y guarda el refresh token en el Keychain. Ofuscar (por ejemplo con GYB) solo es un obstáculo extra.
- Nunca registres secretos en logs ni los mantengas en memoria más de lo necesario.

## Keychain

Úsalo para datos pequeños y sensibles: tokens, claves, licencias. `UserDefaults` es para preferencias. Encapsúlalo en un wrapper tipado y no expongas `SecItem*` al resto de la app.

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,            // dominio lógico
    kSecAttrAccount as String: account,            // registro concreto
    kSecValueData as String: Data(value.utf8),
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]
let status = SecItemAdd(query as CFDictionary, nil)
if status == errSecDuplicateItem { /* SecItemUpdate */ }
```

- `SecItemAdd` no sobrescribe: ante `errSecDuplicateItem`, usa `SecItemUpdate`. Al borrar, trata `errSecItemNotFound` como éxito.
- **Accesibilidad:** `WhenUnlocked` si solo se usa en primer plano. `AfterFirstUnlock` para tareas en segundo plano o extensiones. Las variantes `ThisDeviceOnly` impiden que el dato migre en copias de seguridad.
- **Access groups** (`kSecAttrAccessGroup`, validados por entitlements): compártelo solo si hace falta, porque amplía quién puede leer el secreto.
- `SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.userPresence], &error)` pide Face ID o código. Resérvalo para acciones de alto valor.
- Ciclo de vida: crea, rota y **borra** los secretos al cerrar sesión.

## App Attest y Secure Enclave

- Una clave del Secure Enclave protege la parte privada, pero no demuestra su origen al servidor. App Attest certifica **solo** las claves creadas con `DCAppAttestService.generateKey()`, no cualquier `SecureEnclave.P256`.
- **Registro:** `isSupported`, después `generateKey()` y guardar el `keyID`. El servidor envía un reto aleatorio de un solo uso (32 bytes, con caducidad). La app llama a `attestKey(keyID, clientDataHash: SHA256(reto))`.
- **El servidor valida** el objeto CBOR completo: la cadena hasta la raíz de App Attest, el nonce, el App ID (prefijo y bundle id), la clave frente al keyID, el entorno y el contador. Decodificarlo no basta para confiar en él.
- **Por operación:** `generateAssertion(keyID, clientDataHash: SHA256(payload))` sobre un payload que incluya la acción y un reto nuevo. Envía **esos mismos bytes**. El servidor verifica la firma y que el contador **avance**.
- La clave se invalida al reinstalar, migrar o restaurar. Un fallo de red no es fraude. App Attest no sustituye a la autenticación ni a los permisos.

## TLS sin debilitar HTTPS

- Mantén la evaluación del sistema de `URLSession`. En un delegado, usa `.performDefaultHandling`; nunca `.useCredential` con el `serverTrust` sin evaluar.
- Distingue y propaga `URLError` (`.serverCertificateUntrusted`, `.serverCertificateHasBadDate`, `.serverCertificateNotYetValid`, `.serverCertificateHasUnknownRoot`) de los errores HTTP. No muestres datos vacíos como si la respuesta fuera válida.
- Causas habituales: el dominio no está en el **SAN** (Common Name ya no basta), falta o ha caducado un intermedio, o la cadena es incorrecta. Relajar ATS no arregla un certificado.
- Para diagnosticar: `openssl s_client -connect host:443 -servername host -showcerts -verify_hostname host -verify_return_error`. Confírmalo después en iOS.
- **Pinning** (`NSPinnedDomains` con SHA-256 del SPKI, no del certificado): solo si es imprescindible y con claves de respaldo y un plan de rotación, porque puede dejar sin conexión las versiones ya instaladas.

## Privacy Manifests

`PrivacyInfo.xcprivacy` describe prácticas, no pide permisos. Cada app y cada SDK declara las suyas. Tiene cuatro bloques:

- `NSPrivacyCollectedDataTypes`: tipo, vinculado a la identidad, si es seguimiento y finalidades. Recopilar significa enviar fuera del dispositivo y conservarlo más allá de la petición.
- `NSPrivacyTracking` junto con `NSPrivacyTrackingDomains`: dominios sin protocolo. Deja la lista vacía si `NSPrivacyTracking` es `false`.
- `NSPrivacyAccessedAPITypes`: Required Reason APIs (marcas temporales de ficheros, tiempo desde el arranque, espacio en disco, teclados activos, `UserDefaults`) con el **código exacto**, por ejemplo `NSPrivacyAccessedAPICategoryDiskSpace` con `E174.1`. Nunca declares por si acaso.

Reglas:

- El fingerprinting está prohibido aunque el usuario autorice ATT.
- No copies las declaraciones de un SDK en el manifiesto de la app: actualiza el SDK o reclama al proveedor. Algunos SDK habituales necesitan además una firma.
- Para comprobar, usa `plutil -lint` (solo valida la sintaxis) y Organizer → Generate Privacy Report. Compáralo con la ficha de App Store Connect y revisa cada vez que cambien la analítica, los SDK o los datos que se envían.

## App Tracking Transparency (UE, iOS 27.2)

```swift
@MainActor
func requestTracking() async -> ATTrackingManager.AuthorizationStatus {
    guard UIApplication.shared.applicationState == .active else { return ATTrackingManager.trackingAuthorizationStatus }
    if #available(iOS 27.2, *) {
        return await ATTrackingManager.requestTrackingAuthorization(usingExpandedInterface: true, additionalInformationAction: nil)
    }
    return await ATTrackingManager.requestTrackingAuthorization()
}
```

- Activa los SDK de seguimiento solo con `.authorized` y nunca antes de pedir el permiso.
- `NSUserTrackingUsageDescription` es obligatoria; sin ella la app falla. `NSUserTrackingMarkdownUsageDescription` es opcional y admite negrita, cursiva y listas.
- El sistema decide la región, así que no uses `Locale`. El botón de información adicional cierra sin decisión (`.notDetermined`).
- En la UE se puede volver a preguntar al cabo de un año: revisa los `guard status == .notDetermined`. No condiciones funciones ni ofrezcas incentivos por aceptar.

## Trust Insights (iOS 27)

Antes de operaciones sensibles (cambio de correo de recuperación, pagos):

- Necesita la capability Trust Insights y autorización del usuario.
- La petición es `IsLikelyBeingCoachedInsight.request(schema: .version1, modelVersion: .current)` dentro de un `InsightContext(operationCategory: .account, ...)`, con un `requestID` que debes comprobar en la respuesta.
- Interpreta los resultados así: `.unknown`, controles normales (no significa seguro); `.medium`, verificación extra; `.high`, advertencia con opción de cancelar.
- Llama **siempre** a `evaluation.reportConsumption(...)` (en `defer`); omitirlo puede restringir el servicio. Si decide el servidor, valida allí el `signedPayload`.
- Ante cualquier error o falta de permiso, mantén los controles habituales.

Ver también `firma-y-distribucion` y `persistencia-swiftdata` (CloudKit `encryptedValues`).
