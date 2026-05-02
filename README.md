# Client Tracker

A small Django app for tracking clients.

## Requirements

Minimum 2CPU, 2GB Memory

## Install on Linux

Run these commands from the home folder of the Linux user:

```bash
sudo yum install -y git
cd ~
git clone https://github.com/ikambarov/client_tracker.git
bash client_tracker/scripts/setup_systemd.sh
```

The script installs dependencies, creates `.venv`, runs migrations, loads sample data, installs the `client-tracker` systemd service, and starts the app.

Check the service:

```bash
sudo systemctl status client-tracker
```

Open the app:

```text
http://INSTANCE_PUBLIC_IP/
```

## Reset app

This removes the current app folder, clones a fresh copy, and runs setup again:

```bash
sudo systemctl stop client-tracker
sudo rm -f /etc/client-tracker.env
cd ~
rm -rf client_tracker
git clone https://github.com/ikambarov/client_tracker.git
cd client_tracker
./scripts/setup_systemd.sh
```

## Optional settings

The setup script has defaults. Use environment variables only when you need to override them.

```text
APP_DIR              App folder. Default: $HOME/client_tracker
APP_USER             Linux user for systemd. Default: ec2-user
APP_GROUP            Linux group for systemd. Default: same as APP_USER
PORT                 App port. Default: 80
GUNICORN_WORKERS     Gunicorn worker processes. Default: 2
GUNICORN_TIMEOUT     Request timeout in seconds. Default: 120
DJANGO_ALLOWED_HOSTS Allowed hostnames/IPs. Default: *
DJANGO_DEBUG         Debug mode. Default: False
DATABASE_TYPE        sqlite or mysql. Default: sqlite
```

Example:

```bash
PORT=8080 GUNICORN_WORKERS=3 ./scripts/setup_systemd.sh
```

## MySQL settings

Set `DATABASE_TYPE=mysql` to use MySQL.

```text
DATABASE_TYPE        sqlite or mysql. Default: sqlite
DB_NAME              Database name. Default: client_tracker

DB_HOST              Writer database host. Example: writer-db.example.com
DB_PORT              Writer database port. Default: 3306
DB_USER              Writer database username. Default: admin
DB_PASSWORD          Writer database password. Default: empty
```

Example with writer:

```bash
cd ~/client_tracker
DATABASE_TYPE=mysql \
DB_NAME=client_tracker \
DB_HOST=writer-db.example.com \
DB_PORT=3306 \
DB_USER=writer_user \
DB_PASSWORD=writer-password \
./scripts/setup_systemd.sh
```

Reader variables are optional. If they are not set, the writer database is used for reads and writes.
```text
DB_READER_HOST       Optional reader database host. Example: reader-db.example.com
DB_READER_PORT       Reader database port. Default: 3306
DB_READER_USER       Reader database username. Default: admin
DB_READER_PASSWORD   Reader database password. Default: empty
```

Example with writer and reader:

```bash
cd ~/client_tracker
DATABASE_TYPE=mysql \
DB_NAME=client_tracker \
DB_HOST=writer-db.example.com \
DB_PORT=3306 \
DB_USER=writer_user \
DB_PASSWORD=writer-password \
DB_READER_HOST=reader-db.example.com \
DB_READER_PORT=3306 \
DB_READER_USER=reader_user \
DB_READER_PASSWORD=reader-password \
./scripts/setup_systemd.sh
```

## Benchmark app/db

Run these from the Linux server:

Install ApacheBench before running these `ab` command.

The Home page tests static page reads.
```bash
ab -n 200 -c 10 "http://0.0.0.0/"
```

The Find Clients page tests database reads.
```bash
ab -n 200 -c 10 "http://0.0.0.0/find_client"
```

The add client page tests database writes.
```bash
ab -n 200 -c 10 -p scripts/add-client-post-data.txt -T application/x-www-form-urlencoded "http://0.0.0.0/add_client"
```
