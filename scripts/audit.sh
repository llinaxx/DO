#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"; ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname), $(date '+%Y-%m-%d %H:%M')"

echo " [1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

PORT=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ "$PORT" != "22" ]]; then
    echo " [OK] Порт SSH нестандартный ($PORT)"; ((PASS++))
else
    echo " [FAIL] Порт SSH стандартный (22)"; ((FAIL++))
fi

check "MaxAuthTries равно 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo " [2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

UFW_DEFAULT_IN=$(sudo ufw status verbose | grep Default | awk '{print $2}')
check "Политика по умолчанию для входящих - deny" "deny" "$UFW_DEFAULT_IN"

echo " [3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo " [4] Веб-сервер"
sudo nginx -t >/dev/null 2>&1
check "Конфигурация nginx корректна" "0" "$?"

EXP_DAYS=$(openssl x509 -checkend $((30*24*60*60)) -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo $?)
check "Сертификат истекает не ранее чем через 30 дней" "0" "$EXP_DAYS"

FIND_WW=$(sudo find /var/www/devops-site -perm -o+w 2>/dev/null | wc -l | awk '{print $1}')
check "Нет файлов с правом записи для всех" "0" "$FIND_WW"

KEY_PERMS=$(sudo stat -c '%a' /etc/ssl/private/devops.key)
check "Права ключа 600" "600" "$KEY_PERMS"

echo " [5] Контейнеризация"
check "Служба Docker активна" "active" "$(systemctl is-active docker)"
check "Контейнер БД healthy" "healthy" "$(sudo docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo 'missing')"

PORTS_CHECK=$(sudo ss -tln | awk '{print $4}' | grep -E ':(5000|5432)$' | grep -v '^127.0.0.1:' | wc -l | awk '{print $1}')
check "Порты 5000 и 5432 не прослушиваются извне" "0" "$PORTS_CHECK"

check "Права файла .env 600" "600" "$(stat -c '%a' ~/app/.env 2>/dev/null || echo 'missing')"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
