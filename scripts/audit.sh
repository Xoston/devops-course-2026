#!/bin/bash

FAILED=0

# Функция проверки
check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "[OK] $desc"
    else
        echo "[FAIL] $desc"
        FAILED=1
    fi
}

# --- Здесь могли быть ваши старые проверки [1]-[4] ---
# echo "[1] ..."
# check "..." ...

echo "[5] Контейнеризация"

check "docker service is active" systemctl is-active --quiet docker
check "db container is healthy" bash -c '[ "$(docker inspect -f "{{.State.Health.Status}}" app-db-1 2>/dev/null)" = "healthy" ]'
check "ports 5000/5432 restricted to localhost" bash -c 'bad=$(ss -tlnH | awk "{print \$4}" | grep -E ":(5000|5432)$" | grep -vE "^127\.0\.0\.1:"); [ -z "$bad" ]'
check ".env permissions are 600" bash -c '[ "$(stat -c "%-a" ~/app/.env 2>/dev/null)" = "600" ]'

if [ "$FAILED" -eq 1 ]; then
    exit 1
fi
exit 0
