# client_tracker

A small Django app for tracking clients and generating CPU/database load.

## Install on Linux

Run these commands from the home folder of the Linux user:

```bash
cd ~
git clone https://github.com/ikambarov/client_tracker.git
cd client_tracker
./scripts/setup_systemd.sh
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

## Reconfigure or reset system settings

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

## Use MySQL

SQLite is the default. To use MySQL:

```bash
cd ~/client_tracker
DATABASE_TYPE=mysql \
DB_NAME=client_tracker \
DB_USER=admin \
DB_PASSWORD=replace-with-your-password \
DB_HOST=replace-with-your-mysql-host \
DB_PORT=3306 \
./scripts/setup_systemd.sh
```

## Generate load with existing pages

Run these from the Linux server:

Install ApacheBench before running these `ab` commands.

The home page tests static page reads.
```bash
ab -n 200 -c 10 "http://0.0.0.0/"
```

The find clients page tests database/page reads.
```bash
ab -n 200 -c 10 "http://0.0.0.0/find_client"
```

The add client page tests database/page writes.
```bash
printf 'firstName=Load&lastName=Test&address=1+Load+St&city=Testville&telephone=555-666-0101' | \
  ab -n 100 -c 5 -p /dev/stdin -T application/x-www-form-urlencoded "http://0.0.0.0/add_client"
```
