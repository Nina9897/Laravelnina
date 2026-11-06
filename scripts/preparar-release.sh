#!/usr/bin/env bash
# Uso: scripts/preparar-release.sh v1.0.0
set -euo pipefail

VERSION="${1:-}"
SALIDA="${2:-dist}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: indica una versión con formato vMAYOR.MENOR.PARCHE (ej. v1.0.0)" >&2
  exit 1
fi

RAIZ="$(pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo ">> [1/6] Copiando proyecto limpio (sin archivos sensibles ni de desarrollo)"
tar \
  --exclude='./.git' \
  --exclude='./.github' \
  --exclude='./.env' \
  --exclude='./.env.backup' \
  --exclude='./.env.production' \
  --exclude='./.env.local' \
  --exclude='./node_modules' \
  --exclude='./vendor' \
  --exclude='./tests' \
  --exclude='./docs' \
  --exclude='./dist' \
  --exclude='./.phpunit.cache' \
  --exclude='./.phpunit.result.cache' \
  --exclude='./storage/logs/*' \
  --exclude='./storage/framework/cache/data/*' \
  --exclude='./storage/framework/sessions/*' \
  --exclude='./storage/framework/views/*' \
  --exclude='./bootstrap/cache/*.php' \
  --exclude='./database/*.sqlite' \
  --exclude='./public/hot' \
  -cf - . | tar -xf - -C "$BUILD_DIR"

cd "$BUILD_DIR"

echo ">> [2/6] Instalando dependencias de PRODUCCIÓN (--no-dev)"
composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader

echo ">> [3/6] Compilando recursos del frontend (Vite)"
if [[ -f package.json ]] && grep -q '"build"' package.json; then
  npm install --no-audit --no-fund
  npm run build
  rm -rf node_modules
fi

echo ">> [4/6] Asegurando carpetas que Laravel necesita"
mkdir -p storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
rm -f storage/logs/*.log
for d in storage/logs storage/framework/cache/data storage/framework/sessions storage/framework/views bootstrap/cache; do
  touch "$d/.gitkeep"
done

echo ">> [5/6] Registrando versión"
echo "$VERSION" > VERSION
{
  echo "version=$VERSION"
  echo "commit=${GITHUB_SHA:-desconocido}"
  echo "fecha_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "php=$(php -r 'echo PHP_VERSION;')"
} > BUILD_INFO

echo ">> [6/6] Generando el archivo comprimido"
mkdir -p "$RAIZ/$SALIDA"
ARCHIVO="laravel-release-${VERSION}.tar.gz"
tar -czf "$RAIZ/$SALIDA/$ARCHIVO" -C "$BUILD_DIR" .
( cd "$RAIZ/$SALIDA" && sha256sum "$ARCHIVO" > "$ARCHIVO.sha256" )

echo "Artefacto listo: $SALIDA/$ARCHIVO"
cat "$RAIZ/$SALIDA/$ARCHIVO.sha256"