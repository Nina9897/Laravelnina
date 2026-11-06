#!/usr/bin/env bash
# Uso: scripts/validar-artefacto.sh dist/laravel-release-v1.0.0.tar.gz
set -uo pipefail

ARCHIVO="${1:-}"
if [[ -z "$ARCHIVO" || ! -f "$ARCHIVO" ]]; then
  echo "ERROR: indica la ruta de un archivo .tar.gz existente" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$ARCHIVO" -C "$TMP"

FALLOS=0
ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALLA] $1"; FALLOS=$((FALLOS + 1)); }

echo "Validación del artefacto: $(basename "$ARCHIVO")"
echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

echo "1) Archivos y carpetas que SÍ deben existir"
REQUERIDOS=(
  artisan composer.json composer.lock VERSION BUILD_INFO .env.example
  vendor/autoload.php vendor/laravel/framework
  app bootstrap/app.php config database/migrations
  public/index.php routes/web.php resources/views
  storage/app storage/framework bootstrap/cache
)
[[ -f "$TMP/package.json" ]] && REQUERIDOS+=(public/build/manifest.json)
for r in "${REQUERIDOS[@]}"; do
  [[ -e "$TMP/$r" ]] && ok "existe $r" || fail "falta $r"
done

echo
echo "2) Archivos que NO deben existir (sensibles o de desarrollo)"
[[ -e "$TMP/.env" ]] && fail "contiene .env" || ok "no contiene .env"
OTROS_ENV="$(find "$TMP" -maxdepth 1 -name '.env*' ! -name '*.example' | wc -l)"
[[ "$OTROS_ENV" -eq 0 ]] && ok "no hay otros .env* (solo plantillas .example)" || fail "hay archivos .env* que no son plantilla"
for p in .git .github node_modules tests vendor/phpunit vendor/mockery vendor/fakerphp; do
  [[ -e "$TMP/$p" ]] && fail "contiene $p" || ok "no contiene $p"
done
SQLITE="$(find "$TMP" -name '*.sqlite' -not -path "$TMP/vendor/*" | wc -l)"
[[ "$SQLITE" -eq 0 ]] && ok "sin bases de datos .sqlite locales" || fail "contiene archivos .sqlite"
LOGS="$(find "$TMP/storage/logs" -type f ! -name '.gitkeep' ! -name '.gitignore' 2>/dev/null | wc -l)"
[[ "$LOGS" -eq 0 ]] && ok "sin archivos de log" || fail "contiene archivos de log"

echo
echo "3) Búsqueda de credenciales (fuera de vendor/)"
buscar() {
  local hallazgos
  hallazgos="$(grep -rIlE --exclude-dir=vendor "$2" "$TMP" 2>/dev/null | sed "s#$TMP/##" | grep -v '\.example$' || true)"
  if [[ -z "$hallazgos" ]]; then ok "sin $1"; else fail "posible $1 en: $hallazgos"; fi
}
buscar "APP_KEY real"        'APP_KEY=base64:[A-Za-z0-9+/=]{20,}'
buscar "llave privada"       'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'
buscar "token de GitHub"     'gh[pousr]_[A-Za-z0-9]{30,}'
buscar "llave de acceso AWS" 'AKIA[0-9A-Z]{16}'

echo
echo "4) Información de la versión"
echo "  VERSION  = $(cat "$TMP/VERSION" 2>/dev/null || echo '?')"
sed 's/^/  /' "$TMP/BUILD_INFO" 2>/dev/null
echo "  Tamaño   = $(du -h "$ARCHIVO" | cut -f1)"

echo
if [[ "$FALLOS" -eq 0 ]]; then
  echo "RESULTADO: APROBADO (0 fallas)"
  exit 0
else
  echo "RESULTADO: RECHAZADO ($FALLOS falla(s))"
  exit 1
fi