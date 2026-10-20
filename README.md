# Развертывание стека мониторинга: Prometheus, Node Exporter и Grafana на Ubuntu 24.04

Данное руководство описывает пошаговую установку и настройку стека мониторинга на базе операционной системы Ubuntu 24.04 LTS.

### Способы установки

В репозитории представлены два способа развертывания стенда:
1. **Ручной (пошаговый)** — подробно описан в данном руководстве ниже. Позволяет контролировать каждый этап установки и настройки.
2. **Автоматизированный** — для удобства установка дополнительно вынесена в готовые bash-скрипты, которые находятся в репозитории:
   * `install_prometheus.sh` — установка и настройка Prometheus, а также создание конфигурационного файла.
   * `install_node_exporter.sh` — установка Node Exporter (подходит для всех хостов: Prometheus, Grafana, Node-1, Node-2).
   * `install_grafana.sh` — установка и настройка Grafana.

## Архитектура стенда

| Хостнейм | IP-адрес | Роль | Устанавливаемое ПО |
| :--- | :--- | :--- | :--- |
| LINUX-PROMETHEUS | 192.168.200.33 | Сервер мониторинга | Prometheus, Node Exporter |
| LINUX-GRAFANA | 192.168.200.34 | Визуализация данных | Grafana, Node Exporter |
| LINUX-NODE-1 | 192.168.200.30 | Целевой хост 1 | Node Exporter |
| LINUX-NODE-2 | 192.168.200.31 | Целевой хост 2 | Node Exporter |

Инструкция предполагает, что на всех хостах используется стандартная установка Ubuntu 24.04. Базовые утилиты (wget, tar, nano, gpg) в ней предустановлены и не требуют отдельной инсталляции.

---

## Часть 1. Установка Prometheus и Node Exporter на сервер 192.168.200.33

Подключитесь к серверу 192.168.200.33.

### 1.1 Установка Prometheus

Скачайте и распакуйте дистрибутив:
```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v3.12.0/prometheus-3.12.0.linux-amd64.tar.gz
tar xvfz prometheus-3.12.0.linux-amd64.tar.gz
cd prometheus-3.12.0.linux-amd64
```

Переместите бинарные файлы и создайте необходимые директории:
```bash
sudo mv prometheus /usr/bin/
sudo mv promtool /usr/bin/
sudo mkdir -p /etc/prometheus /etc/prometheus/data
```

Создайте системного пользователя и назначьте права:
```bash
sudo useradd -rs /bin/false prometheus
sudo chown prometheus:prometheus /usr/bin/prometheus /usr/bin/promtool
sudo chown -R prometheus:prometheus /etc/prometheus
```

### 1.2 Создание конфигурационного файла Prometheus

Откройте файл для редактирования:
```bash
sudo nano /etc/prometheus/prometheus.yml
```

Вставьте следующее содержимое (используйте пробелы для отступов):
```yaml
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
          - "192.168.200.33:9100"
          - "192.168.200.34:9100"
          - "192.168.200.30:9100"
          - "192.168.200.31:9100"
```

Проверьте синтаксис конфигурации перед запуском:
```bash
promtool check config /etc/prometheus/prometheus.yml
```

### 1.3 Создание systemd-сервиса для Prometheus

Откройте файл для редактирования:
```bash
sudo nano /etc/systemd/system/prometheus.service
```

Вставьте следующее содержимое:
```ini
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
```

Запустите службу и добавьте ее в автозагрузку:
```bash
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
```

### 1.4 Установка Node Exporter

Скачайте и распакуйте дистрибутив:
```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.12.1.linux-amd64.tar.gz
cd node_exporter-1.12.1.linux-amd64
```

Переместите бинарный файл и создайте пользователя:
```bash
sudo mv node_exporter /usr/bin/
sudo useradd -rs /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/bin/node_exporter
```

Создайте сервисный файл:
```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Вставьте следующее содержимое:
```ini
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
```

Запустите службу и добавьте ее в автозагрузку:
```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

### 1.5 Настройка файрвола UFW

Откройте необходимые порты:
```bash
sudo ufw allow 9090/tcp
sudo ufw allow 9100/tcp
```

---

## Часть 2. Установка Grafana и Node Exporter на сервер 192.168.200.34

Подключитесь к серверу 192.168.200.34.

### 2.1 Установка Grafana

Добавьте GPG-ключ и репозиторий:
```bash
sudo apt update
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
```

Обновите списки пакетов и установите Grafana:
```bash
sudo apt update
sudo apt install grafana -y
```

Запустите службу и добавьте ее в автозагрузку:
```bash
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

### 2.2 Установка Node Exporter

Скачайте и распакуйте дистрибутив:
```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.12.1.linux-amd64.tar.gz
cd node_exporter-1.12.1.linux-amd64
```

Переместите бинарный файл и создайте пользователя:
```bash
sudo mv node_exporter /usr/bin/
sudo useradd -rs /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/bin/node_exporter
```

Создайте сервисный файл:
```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Вставьте следующее содержимое:
```ini
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
```

Запустите службу и добавьте ее в автозагрузку:
```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

### 2.3 Настройка файрвола UFW

Откройте необходимые порты:
```bash
sudo ufw allow 3000/tcp
sudo ufw allow 9100/tcp
sudo ufw reload
```

---

## Часть 3. Установка Node Exporter на сервер 192.168.200.30 (LINUX-NODE-1)

Подключитесь к серверу 192.168.200.30.

### 3.1 Установка Node Exporter

Скачайте и распакуйте дистрибутив:
```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.12.1.linux-amd64.tar.gz
cd node_exporter-1.12.1.linux-amd64
```

Переместите бинарный файл и создайте пользователя:
```bash
sudo mv node_exporter /usr/bin/
sudo useradd -rs /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/bin/node_exporter
```

Создайте сервисный файл:
```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Вставьте следующее содержимое:
```ini
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
```

Запустите службу и добавьте ее в автозагрузку:
```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

Откройте порт в файрволе:
```bash
sudo ufw allow 9100/tcp
```

---

## Часть 4. Установка Node Exporter на сервер 192.168.200.31 (LINUX-NODE-2)

Подключитесь к серверу 192.168.200.31.

### 4.1 Установка Node Exporter

Скачайте и распакуйте дистрибутив:
```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.12.1.linux-amd64.tar.gz
cd node_exporter-1.12.1.linux-amd64
```

Переместите бинарный файл и создайте пользователя:
```bash
sudo mv node_exporter /usr/bin/
sudo useradd -rs /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/bin/node_exporter
```

Создайте сервисный файл:
```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Вставьте следующее содержимое:
```ini
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
```

Запустите службу и добавьте ее в автозагрузку:
```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

Откройте порт в файрволе:
```bash
sudo ufw allow 9100/tcp
```

---

## Часть 5. Настройка источника данных и импорт дашборда в Grafana

1. Откройте веб-браузер и перейдите по адресу: http://192.168.200.34:3000
2. Введите логин `admin` и пароль `admin`. Система предложит сменить пароль, задайте новый.
3. В левом меню выберите Connections (или Configuration, в зависимости от версии интерфейса), затем Data Sources.
4. Нажмите кнопку Add data source и выберите Prometheus.
5. В поле Connection URL укажите: http://192.168.200.33:9090
6. Нажмите кнопку Save & Test. Должно появиться уведомление об успешном подключении.
7. В левом меню перейдите в раздел Dashboards, нажмите New и выберите Import.
8. В поле Import via grafana.com введите ID: 1860 и нажмите Load.
9. В выпадающем списке выберите источник данных Prometheus и нажмите Import.

После импорта дашборда вы сможете переключаться между хостами (Prometheus, Grafana, Node-1, Node-2) в выпадающем списке в верхней части экрана для просмотра метрик их операционных систем.

---

## Возможные проблемы и способы их решения

| Проблема | Решение |
| :--- | :--- |
| Prometheus не запускается (status=2) | Проверьте синтаксис YAML-файла командой `promtool check config /etc/prometheus/prometheus.yml`. Убедитесь, что отступы выполнены пробелами, а не табуляцией. Проверьте права пользователя prometheus на директорию /etc/prometheus/data. |
| Grafana не подключается к Prometheus (connection refused) | Убедитесь, что в конфигурации Prometheus указан адрес `0.0.0.0:9090`. Проверьте статус UFW на сервере 192.168.200.33 командой `sudo ufw status`. С сервера Grafana выполните `curl http://192.168.200.33:9090` для проверки сетевой доступности. |
| Цели (Targets) в Prometheus имеют статус DOWN | Зайдите на сервер Prometheus и проверьте доступность целевого хоста командой `curl http://<IP-адрес_хоста>:9100/metrics`. Убедитесь, что на целевом хосте запущена служба node_exporter (`systemctl status node_exporter`) и открыт порт 9100 в файрволе. |
| Дашборд пустой, хотя цели (Targets) в статусе UP | Подождите 1-2 минуты для сбора первых метрик. Проверьте, что в настройках дашборда выбран правильный источник данных и установлен актуальный временной интервал (например, Last 15 minutes). |
