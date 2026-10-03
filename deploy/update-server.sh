#!/usr/bin/env bash
# Mise à jour de https://boulfrik.optizaworks.com depuis GitHub (YAZNAG/GES-BOULF).
# À lancer sur le serveur en root : bash /home/optizaworks/apps/ges-boulf/deploy/update-server.sh
set -euo pipefail
APP=/home/optizaworks/apps/ges-boulf
PHP=/opt/cpanel/ea-php83/root/usr/bin/php
COMPOSER=/opt/cpanel/composer/bin/composer
run() { sudo -u optizaworks "$@"; }

cd "$APP"
run git pull --ff-only
cd "$APP/backend"
run "$PHP" "$COMPOSER" install --no-dev --optimize-autoloader --no-interaction
run "$PHP" artisan migrate --force
run "$PHP" artisan storage:link 2>/dev/null || true
run "$PHP" artisan optimize

# Front React : compilé puis copié dans le dossier public de Laravel (même domaine que /api).
cd "$APP/frontend"
run npm ci --no-audit --no-fund
run npm run build
run rsync -a --exclude index.php --exclude .htaccess --exclude storage --exclude robots.txt --exclude favicon.ico \
  --exclude build --exclude 'vendor' "$APP/frontend/dist/" "$APP/backend/public/"
echo "Mise à jour terminée."
