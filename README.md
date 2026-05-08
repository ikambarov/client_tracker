# Client Tracker

A small Django app for tracking clients.

## Requirements

- Minimum 1CPU, 1GB Memory
- Python 3.12 or newer

## Install on Linux

Run these commands from the home folder of the Linux user:

```bash
sudo yum install -y git
sudo git clone https://github.com/ikambarov/client_tracker.git /app
sudo bash /app/scripts/setup_systemd.sh
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
sudo rm -rf /app
sudo git clone https://github.com/ikambarov/client_tracker.git /app
sudo bash /app/scripts/setup_systemd.sh
```

## Optional settings

The setup script has defaults. Use command-line options only when you need to override them.

```text
--app-dir PATH                App folder. Default: /app
--app-user USER               Linux user for systemd. Default: ec2-user
--app-group GROUP             Linux group for systemd. Default: same as --app-user
--port PORT                   App port. Default: 80
--gunicorn-workers COUNT      Gunicorn worker processes. Default: 2
--gunicorn-timeout SECONDS    Request timeout in seconds. Default: 120
--python-bin PATH             Python 3.12+ interpreter. Default: python3.12
--django-allowed-hosts VALUE  Allowed hostnames/IPs. Default: *
--django-debug true|false     Debug mode. Default: False
--database-type sqlite|mysql  Database type. Default: sqlite
--help                        Show all setup options
```

Example:

```bash
./scripts/setup_systemd.sh --port 8080 --gunicorn-workers 3
```

## MySQL settings

Set `--database-type mysql` to use MySQL.

```text
--database-type TYPE  sqlite or mysql. Default: sqlite
--db-name NAME        Database name. Default: client_tracker

--db-host HOST        Writer database host. Example: writer-db.example.com
--db-port PORT        Writer database port. Default: 3306
--db-user USER        Writer database username. Default: admin
--db-password VALUE   Writer database password. Default: empty
```

Example with writer:

```bash
cd ~/client_tracker
./scripts/setup_systemd.sh \
  --database-type mysql \
  --db-name client_tracker \
  --db-host writer-db.example.com \
  --db-port 3306 \
  --db-user writer_user \
  --db-password writer-password
```

Reader variables are optional. If they are not set, the writer database is used for reads and writes.
```text
--db-reader-host HOST       Optional reader database host. Example: reader-db.example.com
--db-reader-port PORT       Reader database port. Default: writer port
--db-reader-user USER       Reader database username. Default: admin
--db-reader-password VALUE  Reader database password. Default: empty
```

Example with writer and reader:

```bash
cd ~/client_tracker
./scripts/setup_systemd.sh \
  --database-type mysql \
  --db-name client_tracker \
  --db-host writer-db.example.com \
  --db-port 3306 \
  --db-user writer_user \
  --db-password writer-password \
  --db-reader-host reader-db.example.com \
  --db-reader-port 3306 \
  --db-reader-user reader_user \
  --db-reader-password reader-password
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
