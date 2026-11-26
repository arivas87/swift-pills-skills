#!/usr/bin/env bash
# Instala las skills de Swift Pills sin usar el sistema de plugins.
# Enlaza (o copia) cada carpeta de plugins/swift-pills/skills/ en el directorio
# de skills personal de la herramienta elegida.
#
# Uso:
#   scripts/instalar.sh claude          # ~/.claude/skills
#   scripts/instalar.sh codex           # ~/.agents/skills
#   scripts/instalar.sh todos           # ambos
#   scripts/instalar.sh codex --copiar  # copia en vez de enlazar
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
origen="$raiz/plugins/swift-pills/skills"
destino_herramienta="${1:-}"
modo="${2:-}"

destinos=()
case "$destino_herramienta" in
  claude) destinos=("$HOME/.claude/skills") ;;
  codex)  destinos=("$HOME/.agents/skills") ;;
  todos)  destinos=("$HOME/.claude/skills" "$HOME/.agents/skills") ;;
  *) echo "Uso: $0 claude|codex|todos [--copiar]" >&2; exit 64 ;;
esac

instaladas=0
for destino in "${destinos[@]}"; do
  mkdir -p "$destino"
  for skill in "$origen"/*/; do
    [ -f "$skill/SKILL.md" ] || continue
    nombre="$(basename "$skill")"
    objetivo="$destino/$nombre"
    if [ -e "$objetivo" ] && [ ! -L "$objetivo" ]; then
      echo "Omitida $nombre: ya existe $objetivo y no es un enlace de este repositorio." >&2
      continue
    fi
    rm -f "$objetivo"
    if [ "$modo" = "--copiar" ]; then
      cp -R "$skill" "$objetivo"
    else
      ln -s "${skill%/}" "$objetivo"
    fi
    echo "Instalada $nombre en $destino"
    instaladas=$((instaladas + 1))
  done
done

[ "$instaladas" -gt 0 ] || echo "No hay skills que instalar todavía."
echo "Reinicia Claude Code o Codex para que carguen las skills nuevas."
