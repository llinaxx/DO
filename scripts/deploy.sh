#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# Проверка 4: файл site/index.html существует
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл ${LOCAL_DIR}index.html не найден!" >&2
    exit 1
fi

# Проверка 5: нет незафиксированных изменений
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
    exit 1
fi

# Проверка 8 и 9: не более одного SSH-соединения и без запроса пароля
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5 -o ControlMaster=auto -o ControlPath=/tmp/ssh-deploy-%r@%h:%p -o ControlPersist=60"

# Синхронизация
RSYNC_CMD="/opt/homebrew/bin/rsync"
if [[ ! -x "$RSYNC_CMD" ]]; then RSYNC_CMD="rsync"; fi

$RSYNC_CMD -avz --delete --chmod=D755,F644 $DRY_RUN -e "ssh $SSH_OPTS" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

if [[ -n "$DRY_RUN" ]]; then
    echo "Пробный запуск завершен."
    exit 0
fi

# Проверка 6: проверка доступности с проверкой сертификата
if ! curl -fsS --cacert "${CA_CERT}" -I "${SITE_URL}" > /dev/null; then
    echo "Ошибка: Сайт ${SITE_URL} недоступен!" >&2
    exit 1
fi

# Проверка 7: вывод короткого хеша коммита
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Успешно доставлено. Коммит: ${COMMIT_HASH}"
exit 0
