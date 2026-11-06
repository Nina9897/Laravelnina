#!/usr/bin/env bash
# Uso: scripts/desplegar-preproduccion.sh dist/laravel-release-v1.0.0.tar.gz [DIRECTORIO_BASE]
set -euo pipefail

ARCHIVO="${1:-}"
BASE="${2:-/tmp/preprod}"
PLANTILLA_ENV=".env.preproduccion.example"
PUERTO_PRUEBA="${PUERTO_PRUEBA:-8099}"

if [[ -z "$ARCHIVO" || ! -f "$ARCHIVO" ]]; then
  echo "ERROR: indica la ruta del artefacto .tar.gz" >&2
  exit 2
fi

VERSION="$(tar -xzOf "$ARCHIVO" ./VERSION | tr -d '[:space:]')"
RELEASE="$BASE/releases/$VERSION"
COMPARTIDO="$BASE/shared"

echo ">> [1/7] Preparando carpetas en $BASE"
mkdir -p "$BASE/releases" "$COMPARTIDO"
rm -rf "$RELEASE"
mkdir -p "$RELEASE"

echo ">> [2/7] Descomprimiendo versión $VERSION"
tar -xzf "$ARCHIVO" -C "$RELEASE"

echo ">> [3/7] Configurando variables de entorno de preproducción"
if [[ ! -f "$COMPARTIDO/.env" ]]; then
  cp "$RELEASE/$PLANTILLA_ENV" "$COMPARTIDO/.env"
  sed -i "s#^DB_DATABASE=.*#DB_DATABASE=$COMPARTIDO/database.sqlite#" "$COMPARTIDO/.env"
  touch "$COMPARTIDO/database.sqlite"
fi
ln -sfn "$COMPARTIDO/.env" "$RELEASE/.env"

if ! grep -qE '^APP_KEY=base64:' "$COMPARTIDO/.env"; then
  ( cd "$RELEASE" && php artisan key:generate --force --no-interaction )
fi

echo ">> [4/7] Ajustando permisos de storage/ y bootstrap/cache/"
chmod -R ug+rwX "$RELEASE/storage" "$RELEASE/bootstrap/cache"
chmod 660 "$COMPARTIDO/database.sqlite"
if [[ "$(id -u)" -eq 0 ]] && id www-data >/dev/null 2>&1; then
  chown -R www-data:www-data "$RELEASE/storage" "$RELEASE/bootstrap/cache" "$COMPARTIDO"
fi

echo ">> [5/7] Preparando la aplicación (migraciones y cachés)"
cd "$RELEASE"
php artisan migrate --force --no-interaction
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo ">> [6/7] Activando la versión (enlace 'current')"
ln -sfn "$RELEASE" "$BASE/current"
( cd "$BASE/releases" && ls -1t | tail -n +4 | xargs -r rm -rf )

echo ">> [7/7] Prueba de humo: ¿responde la aplicación?"
php -S "127.0.0.1:$PUERTO_PRUEBA" -t "$BASE/current/public" >/dev/null 2>&1 &
SERVIDOR=$!
trap 'kill $SERVIDOR 2>/dev/null || true' EXIT
sleep 2
CODIGO="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PUERTO_PRUEBA/")"
echo "   GET / -> HTTP $CODIGO"
if [[ "$CODIGO" != "200" ]]; then
  echo "ERROR: la aplicación no respondió 200 en preproducción" >&2
  exit 1
fi

echo "DESPLIEGUE EXITOSO: versión $VERSION activa en $BASE/current"