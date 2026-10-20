#!/bin/bash
# Установка Prometheus 3.12.0 на Ubuntu 24.04 (IP: 192.168.200.33)
# Требует прав root (sudo)

set -e  # Остановка при любой ошибке

if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите с sudo: sudo ./install_prometheus.sh"
  exit 1
fi

echo "=== Обновление списка пакетов ==="
apt update

echo "=== Скачивание и распаковка Prometheus ==="
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v3.12.0/prometheus-3.12.0.linux-amd64.tar.gz
tar xvfz prometheus-3.12.0.linux-amd64.tar.gz
cd prometheus-3.12.0.linux-amd64

echo "=== Установка бинарных файлов ==="
mv prometheus /usr/bin/
mv promtool /usr/bin/

echo "=== Создание служебного пользователя ==="
useradd -rs /bin/false prometheus || true
chown prometheus:prometheus /usr/bin/prometheus /usr/bin/promtool

echo "=== Создание директорий ==="
mkdir -p /etc/prometheus /etc/prometheus/data
chown -R prometheus:prometheus /etc/prometheus

echo "=== Создание конфигурационного файла /etc/prometheus/prometheus.yml ==="
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["192.168.200.33:9090"]

  - job_name: "node_exporter"
    static_configs:
      - targets: 
          - "192.168.200.33:9100" # Prometheus
          - "192.168.200.34:9100" # Grafana
          - "192.168.200.30:9100" # Node-1
          - "192.168.200.31:9100" # Node-2
EOF

echo "=== Проверка синтаксиса конфигурации ==="
promtool check config /etc/prometheus/prometheus.yml

echo "=== Создание systemd-сервиса ==="
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /etc/prometheus/data \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

echo "=== Запуск и включение автозапуска ==="
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

echo "=== Настройка UFW ==="
ufw allow 9090/tcp
ufw allow 9100/tcp

echo "=== Готово! ==="
echo "Веб-интерфейс Prometheus доступен по адресу: http://192.168.200.33:9090"