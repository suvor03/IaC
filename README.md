# IaC configuration management lab

Лабораторная работа по созданию трёх Docker-узлов средствами Terraform и настройке их целевого состояния средствами Ansible. Terraform создаёт сеть и контейнеры `node-1` (Nginx), `node-2` (Python/Gunicorn) и `node-3` (PostgreSQL), а также генерирует для них Ansible inventory. Повторное применение playbook возвращает узлы к описанной конфигурации.

## Структура

```text
terraform/                 Terraform-конфигурация, сеть, контейнеры и inventory
ansible/site.yml           Bootstrap Python и запуск ролей
ansible/roles/web          Nginx и статическая главная страница
ansible/roles/app          WSGI-приложение и Gunicorn
ansible/roles/db           PostgreSQL
```

## Требования

- Docker Engine и доступ к его сокету;
- Terraform 1.5 или новее;
- Ansible и Docker CLI;
- коллекция Ansible `community.docker`.

## Развёртывание

Из корня репозитория выполните:

```sh
cd terraform
terraform init
terraform validate
terraform apply
cd ../ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini site.yml
ansible-playbook -i inventory.ini site.yml
```

При первом `terraform apply` Terraform загрузит `ubuntu:22.04`, создаст bridge-сеть и три контейнера. Файл `ansible/inventory.ini` генерируется Terraform и поэтому появится после применения инфраструктуры. Вторая команда Ansible должна завершиться без изменений, если желаемое состояние уже достигнуто.

Сервис Nginx доступен на `http://localhost:8080`, Gunicorn — на `http://localhost:8000`. PostgreSQL работает внутри изолированной Docker-сети и не публикует порт на хост.

Если Docker CLI использует нестандартный сокет, задайте `DOCKER_HOST` перед Terraform и Ansible. Например, для OrbStack на macOS:

```sh
export DOCKER_HOST="unix://$HOME/.orbstack/run/docker.sock"
```

## Проверка дрейфа конфигурации

Удалите пакет Nginx и его серверный компонент, чтобы изменить фактическое состояние:

```sh
docker exec -it node-1 apt-get remove -y nginx nginx-core
docker exec node-1 sh -c 'pkill -TERM -x nginx || true'
```

Проверьте, что бинарный файл отсутствует, затем примените playbook ещё раз:

```sh
docker exec node-1 sh -c 'test ! -x /usr/sbin/nginx'
cd ansible
ansible-playbook -i inventory.ini site.yml
docker exec node-1 nginx -t
curl -fsS http://localhost:8080
```

Ansible установит отсутствующий пакет, восстановит конфигурацию и запустит Nginx. В журнале выполнения задачи установки и запуска покажут `changed`.

## Очистка

```sh
cd terraform
terraform destroy
```

Команда удалит созданные контейнеры, сеть и сгенерированный inventory. Terraform state и lock-файл остаются локальными артефактами; state не следует помещать в открытый репозиторий.
