# Install on Lambda

These instructions are to run this app in AWS Lambda.

## Environment variables

Required:

- `DJANGO_SECRET_KEY`

Optional:

- `DJANGO_DEBUG` default `False`
- `DJANGO_ALLOWED_HOSTS` default `*`

Required, with single MySQL database:

- `DATABASE_TYPE` set to `mysql`
- `DB_HOST` example: writer-db.example.com
- `DB_NAME` default `client_tracker`
- `DB_PORT` default `3306`
- `DB_USER` default `admin`
- `DB_PASSWORD` default empty

Optional, with writer/reader MySQL databases:

- `DB_READER_HOST` default empty
- `DB_READER_PORT` default same as `DB_PORT`
- `DB_READER_USER` default `admin`
- `DB_READER_PASSWORD` default empty

## Package

Run this from the project folder:

```bash
./package_lambda.sh
```

Upload `dist/client-tracker-lambda.zip` to Lambda.

Set the Lambda handler:

```text
lambda_function.lambda_handler
```

## Initialize database

Set the database initialization Lambda handler:

```text
lambda_function.migrations_handler
```

This handler runs migrations and loads the sample client data.

Temporarily, increase Memory to 512M and Timeout to 10 minutes.

## IAM permissions

Attach these AWS managed policies to the Lambda execution role:

```text
AWSLambdaBasicExecutionRole
AWSLambdaVPCAccessExecutionRole
```
