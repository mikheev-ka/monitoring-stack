#!/bin/bash
# Установка Node Exporter 1.12.1 на Ubuntu 24.04
# Требует прав root (sudo)

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите с sudo: sudo ./install_node_exporter.sh"
  exit 1
fi

echo "=== Обновление списка пакетов ==="
apt update

echo "=== Скачивание и распаковка Node Exporter ==="
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.12.1.linux-amd64.tar.gz
cd node_exporter-1.12.1.linux-amd64

echo "=== Установка бинарного файла ==="
mv node_exporter /usr/bin/

echo "=== Создание служебного пользователя ==="
useradd -rs /bin/false node_exporter || true
chown node_exporter:node_exporter /usr/bin/node_exporter

echo "=== Создание systemd-сервиса /etc/systemd/system/node_exporter.service ==="
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

echo "=== Запуск и включение автозапуска ==="
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

echo "=== Настройка UFW ==="
ufw allow 9100/tcp

echo "=== Проверка статуса ==="
systemctl status node_exporter --no-pager

echo "=== Проверка доступности метрик ==="
curl -s http://localhost:9100/metrics | head -n 5

echo "=== Готово! ==="
echo "Node Exporter успешно запущен на порту 9100"
echo "IP-адрес этого хоста: $(hostname -I | awk '{print $1}')"