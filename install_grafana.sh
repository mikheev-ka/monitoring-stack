#!/bin/bash
# Установка Grafana на Ubuntu 24.04 (IP: 192.168.200.34)
# Требует прав root (sudo)

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите с sudo: sudo ./install_grafana.sh"
  exit 1
fi

echo "=== Обновление списка пакетов ==="
apt update

echo "=== Добавление официального репозитория Grafana ==="
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

echo "=== Установка Grafana ==="
apt update
apt install -y grafana

echo "=== Запуск и включение автозапуска ==="
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

echo "=== Настройка UFW ==="
ufw allow 3000/tcp
ufw allow 9100/tcp
ufw reload

echo "=== Проверка статуса ==="
systemctl status grafana-server --no-pager

echo "=== Готово! ==="
echo "Веб-интерфейс Grafana доступен по адресу: http://192.168.200.34:3000"
echo "Логин/пароль по умолчанию: admin/admin (при первом входе смените пароль)"
echo ""
echo "Далее в интерфейсе Grafana добавьте источник данных Prometheus:"
echo "  URL: http://192.168.200.33:9090"
echo ""
echo "ВАЖНО: Не забудьте также запустить скрипт install_node_exporter.sh на этом сервере,"
echo "чтобы Grafana могла собирать метрики самой себя."