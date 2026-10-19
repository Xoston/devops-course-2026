#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

# Исправление путей для Windows (Git Bash)
REPO_ROOT="$(git rev-parse --show-toplevel)"
if command -v cygpath >/dev/null 2>&1; then
    REPO_ROOT="$(cygpath -u "${REPO_ROOT}")"
fi
LOCAL_DIR="${REPO_ROOT}/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 1
fi

# 2. Проверки (требования 4 и 5)
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Error: ${LOCAL_DIR}/index.html not found" >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: uncommitted changes in repository. Commit them first." >&2
    exit 1
fi

COMMIT_HASH="$(git rev-parse --short HEAD)"

# Настройка SSH, чтобы не запрашивало пароль (требование 9)
RSYNC_SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"
RSYNC_OPTS=(-avz --delete --chmod=D755,F644 -e "${RSYNC_SSH}")

# 3. Синхронизация
if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "DRY RUN: rsync ${RSYNC_OPTS[*]} ${LOCAL_DIR} ${REMOTE}:${REMOTE_DIR}/"
    rsync "${RSYNC_OPTS[@]}" --dry-run "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
    exit 0
fi

rsync "${RSYNC_OPTS[@]}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 4. Проверка доступности (требование 6)
# Добавлены таймауты --connect-timeout 5 и --max-time 10
if ! curl -fsS --connect-timeout 5 --max-time 10 --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}/"; then
    echo "Error: site ${SITE_URL} is not available or certificate invalid" >&2
    exit 1
fi

# 5. Успешное завершение (требование 7)
echo "Deployed commit: ${COMMIT_HASH}"
exit 0
