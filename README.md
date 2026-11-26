# Swift Pills Skills

Skills para **Claude Code** y **Codex** sobre Swift, SwiftUI, concurrencia, SwiftData y las plataformas de Apple. Salen de los artículos de [Swift Pills](https://swiftpills.dev). Cada skill reúne lo que dicen varios artículos sobre un mismo tema, y se actualiza cuando se publica un artículo nuevo.

Las skills usan el formato `SKILL.md`, que entienden las dos herramientas. El repositorio funciona a la vez como marketplace de plugins de Claude Code y de Codex.

## Instalación en Claude Code

Dentro de una sesión de Claude Code:

```text
/plugin marketplace add arivas87/swift-pills-skills
/plugin install swift-pills@swift-pills
```

Desde la terminal:

```bash
claude plugin marketplace add arivas87/swift-pills-skills
```

```bash
claude plugin install swift-pills@swift-pills
```

Las skills aparecen con el prefijo del plugin, por ejemplo `/swift-pills:swiftdata`. Claude también las carga solo cuando la tarea encaja con su descripción.

**Actualizar:**

```bash
claude plugin marketplace update swift-pills
```

```bash
claude plugin update swift-pills@swift-pills
```

**Para todo un equipo:** instala el plugin con `--scope project` y haz commit de `.claude/settings.json` en el proyecto:

```bash
claude plugin install swift-pills@swift-pills --scope project
```

## Instalación en Codex

Añade el marketplace desde la terminal:

```bash
codex plugin marketplace add arivas87/swift-pills-skills
```

Después abre `codex`, ejecuta `/plugins`, instala **Swift Pills** y empieza una sesión nueva. En Codex las skills se invocan con `$`, por ejemplo `$swiftdata`, y también se cargan solas cuando la tarea encaja.

**Actualizar:**

```bash
codex plugin marketplace upgrade swift-pills
```

Los plugins necesitan una versión reciente de Codex. Si `codex plugin` no existe en tu versión, actualiza Codex o usa la instalación manual.

## Instalación manual, sin plugins

Las dos herramientas cargan skills sueltas desde una carpeta personal: `~/.claude/skills` en Claude Code y `~/.agents/skills` en Codex. Clona el repositorio y enlaza las skills:

```bash
git clone https://github.com/arivas87/swift-pills-skills.git ~/swift-pills-skills
```

```bash
~/swift-pills-skills/scripts/instalar.sh todos
```

Usa `claude` o `codex` en lugar de `todos` para instalarlas en una sola herramienta. El script crea enlaces simbólicos, así que `git pull` basta para actualizarlas. Con `--copiar` las copia en vez de enlazarlas. Reinicia la herramienta después de instalar.

En Codex también puedes instalar una sola skill con el instalador integrado:

```text
$skill-installer install https://github.com/arivas87/swift-pills-skills/tree/main/plugins/swift-pills/skills/<nombre-de-la-skill>
```

## Skills disponibles

21 skills generadas a partir de 170 artículos. Los artículos que alimentan cada skill aparecen en `metadata.fuentes`, en el frontmatter de su `SKILL.md`.

| Skill | Qué cubre | Artículos |
|---|---|---:|
| `animaciones-swiftui` | Animaciones y respuesta sensorial en SwiftUI. | 7 |
| `ciclo-de-vida-swiftui` | Ciclo de vida de vistas, tareas y escenas en SwiftUI. | 7 |
| `concurrencia-swift` | Swift Concurrency en Swift 6, 6.2 y 6.4. | 14 |
| `controles-swiftui` | Controles e interacción en SwiftUI. | 12 |
| `diagnostico-apps` | Diagnóstico y observabilidad de apps Apple en producción y desarrollo. | 4 |
| `estado-swiftui` | Flujo de datos y estado en SwiftUI con Observation. | 10 |
| `firma-y-distribucion` | Firma, compilación, automatización y distribución de apps Apple. | 6 |
| `foundation-models` | IA en apps Apple con el framework Foundation Models. | 7 |
| `integraciones-sistema-ios` | Integraciones de una app con el sistema en iOS y watchOS. | 8 |
| `iphone-duo` | Preparar apps para iPhone Duo, el iPhone plegable, con iOS 27.1. | 7 |
| `layout-swiftui` | Layout adaptativo en SwiftUI para ventanas redimensionables. | 10 |
| `lenguaje-swift` | Fundamentos y novedades del lenguaje Swift hasta Swift 6.4. | 20 |
| `memoria-swift` | Gestión de memoria en Swift con ARC. | 6 |
| `migracion-ios-27` | Preparar una app para el SDK de iOS 27 y Xcode 27. | 4 |
| `persistencia-swiftdata` | Persistencia con SwiftData, CloudKit y ficheros compartidos. | 7 |
| `presentaciones-swiftui` | Presentaciones, navegación y barras de herramientas en SwiftUI. | 8 |
| `previews-y-tests` | Previews de SwiftUI rápidas y reproducibles, y tests con Swift Testing. | 4 |
| `rendimiento-swiftui` | Rendimiento de SwiftUI y cómo evitar reevaluaciones de body innecesarias. | 7 |
| `seguridad-privacidad-ios` | Seguridad y privacidad en apps iOS. | 7 |
| `swift-multiplataforma` | Swift fuera de las apps de Apple. | 7 |
| `texto-y-formato-swiftui` | Texto, formato y tipografía en SwiftUI y Foundation. | 8 |

## Estructura

```text
.claude-plugin/marketplace.json     Marketplace de Claude Code (Codex también lo lee)
.agents/plugins/marketplace.json    Marketplace de Codex
plugins/swift-pills/
  .claude-plugin/plugin.json        Manifiesto para Claude Code
  plugin.json                       Manifiesto portable para Codex
  skills/<nombre>/SKILL.md          Una carpeta por skill, compartida por las dos herramientas
scripts/instalar.sh                 Instalación manual en ~/.claude/skills o ~/.agents/skills
```

## Licencia

[MIT](LICENSE).
