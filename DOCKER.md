# Install on Docker

## Install

With Docker and Git installed, run these commands from the home folder of the Linux user:

```bash
git clone https://github.com/ikambarov/client_tracker.git
cd client_tracker
docker run -d --name client-tracker \
  -p 80:8000 \
  -v "$PWD:/app" \
  -w /app \
  python:3.12-alpine \
  sh -c 'pip install --no-cache-dir -r requirements.txt && exec sh scripts/start_docker.sh --load-sample-data true'
```

This installs dependencies inside the container and runs `scripts/start_docker.sh` from `/app`. The script runs migrations, loads sample data if there are no clients, collects static files, and starts Gunicorn.

The project folder is mounted at `/app`, so the default SQLite database (`db.sqlite3`) remains in that folder when the container is removed.

Check the container:

```bash
docker ps --filter name=client-tracker
docker logs client-tracker
```

Open the app:

```text
http://INSTANCE_PUBLIC_IP/
```

## Restart app

```bash
docker restart client-tracker
```

To change container settings, remove the container and run the installation command again with the new settings:

```bash
docker rm -f client-tracker
```

## Optional settings

The startup script has defaults. Add command-line options to `scripts/start_docker.sh` only when you need to override them.

```text
--port PORT                   App port inside the container. Default: 8000
--gunicorn-workers COUNT      Gunicorn worker processes. Default: 2
--gunicorn-timeout SECONDS    Request timeout in seconds. Default: 120
--run-migrations true|false   Run migrations. Default: true
--collect-static true|false   Collect static files. Default: true
--load-sample-data true|false Load sample clients. Default: false
--django-secret-key VALUE     Django secret key. Default: dev-secret-key
--django-allowed-hosts VALUE  Allowed hostnames/IPs. Default: *
--database-type sqlite|mysql  Database type. Default: sqlite
--help                       Show all startup options
```

For example, replace the final command in the installation example with:

```bash
sh -c 'pip install --no-cache-dir -r requirements.txt && exec sh scripts/start_docker.sh --port 8080 --gunicorn-workers 3'
```

Also change the port mapping to `-p 80:8080` to match the new container port.

Options can also be set through environment variables passed with `docker run -e`, such as `-e GUNICORN_WORKERS=3`. Set `DJANGO_SECRET_KEY` to your own secret for production.

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

Example with writer, run from the project folder instead of the default installation command:

```bash
docker run -d --name client-tracker \
  -p 80:8000 \
  -v "$PWD:/app" \
  -w /app \
  -e DATABASE_TYPE=mysql \
  -e DB_NAME=client_tracker \
  -e DB_HOST=writer-db.example.com \
  -e DB_PORT=3306 \
  -e DB_USER=writer_user \
  -e DB_PASSWORD=writer-password \
  python:3.12-alpine \
  sh -c 'pip install --no-cache-dir -r requirements.txt && exec sh scripts/start_docker.sh --load-sample-data true'
```

Reader variables are optional. If they are not set, the writer database is used for reads and writes. Pass these with `docker run -e` before the image name:

```text
DB_READER_HOST      Reader database host. Default: empty
DB_READER_PORT      Reader database port. Default: writer port
DB_READER_USER      Reader database username. Default: admin
DB_READER_PASSWORD  Reader database password. Default: empty
```

Example additions for a reader:

```bash
-e DB_READER_HOST=reader-db.example.com \
-e DB_READER_PORT=3306 \
-e DB_READER_USER=reader_user \
-e DB_READER_PASSWORD=reader-password
```

## Benchmark app/db

Install ApacheBench on the Docker host, then run these commands from the project folder.

The Home page tests static page reads.

```bash
ab -n 200 -c 10 "http://127.0.0.1/"
```

The Find Clients page tests database reads.

```bash
ab -n 200 -c 10 "http://127.0.0.1/find_client"
```

The Add Client page tests database writes.

```bash
ab -n 200 -c 10 -p scripts/add-client-post-data.txt -T application/x-www-form-urlencoded "http://127.0.0.1/add_client"
```
