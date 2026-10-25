# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Объем памяти: 2 ГБ (2048 МБ)
- Количество ядер: 2
- Объем диска: 25 ГБ

## 2. Сетевые интерфейсы
- Тип адаптера: Виртуализированный VLAN (в UTM)
- Полученный IP-адрес (внутренний): 10.0.2.15
- Проброс портов: хост 2222 -> гость 2222 (настроено через аргументы QEMU)

## 3. Учётные записи
- `student`: принадлежит к группе `sudo`, вход по паролю.
- `devops`: принадлежит к группе `sudo`, вход по ключу `~/.ssh/devops_vm`.

## 4. Служба SSH
- Порт: 2222
- Расположение файла конфигурации: `/etc/ssh/sshd_config.d/99-hardening.conf`
- Изменённые директивы:
  - PermitRootLogin no
  - PasswordAuthentication no
  - MaxAuthTries 3
  - AllowUsers devops

## 5. Правила межсетевого экрана (UFW)
- Политика по умолчанию для входящих: deny
- Политика по умолчанию для исходящих: allow
- Правила:
  - 2222/tcp LIMIT (SSH)
  - 80/tcp ALLOW (HTTP)
  - 443/tcp ALLOW (HTTPS)

## 6. Снимки состояния
- `01-clean-install`: создан после чистой установки ОС.
- `02-keys-configured`: создан после настройки входа по SSH-ключам.
- `03-ssh-hardened`: создан после ужесточения конфигурации SSH.
- `04-dns-configured`: создан после настройки доменного имени.

## 8. Веб-сервер
- Устанавливаемый пакет: nginx
- Путь к конфигурации ресурса: /etc/nginx/sites-available/devops-site
- Каталог ресурса: /var/www/devops-site, владелец devops, права 755.
- Путь к сертификату: /etc/ssl/certs/devops.crt, права 644.
- Путь к ключу: /etc/ssl/private/devops.key, права 600, владелец root.
- Команда формирования сертификата: sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ... -out ... -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"
- Срок действия сертификата: 365 дней.

## 9. Контейнеризация
- Способ установки Docker: официальный репозиторий Docker (docker-ce, docker-compose-plugin).
- Версия Docker: 29.1.3.
- Участники группы docker: пользователь devops.
- Расположение проекта на сервере: ~/app
- Расположение файла .env: ~/app/.env, права 600.
- Публикуемые порты: 127.0.0.1:5000:5000 (только на localhost).
- Именованные тома: db_data (том app_db_data).
- Конфигурация обратного прокси: location /app/ { proxy_pass http://127.0.0.1:5000/; }
