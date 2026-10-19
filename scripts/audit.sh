#!/usr/bin/env bash
set -uo pipefail

# Отключаем конвертацию путей Windows глобально
export MSYS_NO_PATHCONV=1

SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5 -q"

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo -e "[\e[32mOK\e[0m] $desc"
        return 0
    else
        echo -e "[\e[31mFAIL\e[0m] $desc"
        return 1
    fi
}

EXIT_CODE=0

echo "[1] Базовая доступность"
check "SSH подключение" ssh $SSH_OPTS devops "true" || EXIT_CODE=1

echo ""
echo "[4] Веб-сервер"
check "nginx active" ssh $SSH_OPTS devops "systemctl is-active nginx" || EXIT_CODE=1
check "nginx config valid" ssh $SSH_OPTS devops "sudo -n nginx -t" || EXIT_CODE=1
check "cert expires >30 days" ssh $SSH_OPTS devops "openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt" || EXIT_CODE=1
check "no world-writable files" bash -c "! ssh $SSH_OPTS devops 'find /var/www/devops-site -perm -o+w | grep -q .'" || EXIT_CODE=1

# Одинарные кавычки защищают команду от вмешательства Git Bash. Сервер сам вычислит test.
#check "key permissions 600" ssh $SSH_OPTS devops 'test $(sudo -n stat -c "%a" /etc/ssl/private/devops.key) = 600' || EXIT_CODE=1

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "Все проверки пройдены успешно."
else
    echo "Некоторые проверки не пройдены!"
fi

exit $EXIT_CODE
