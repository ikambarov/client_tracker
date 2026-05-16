import os
from io import StringIO

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'client_tracker.settings')

from apig_wsgi import make_lambda_handler
from django.core.management import call_command

from client_tracker.wsgi import application

http_handler = make_lambda_handler(application)


def migrations_handler(event, context):
    stdout = StringIO()
    stderr = StringIO()
    call_command('migrate', '--noinput', stdout=stdout, stderr=stderr)
    call_command('loaddata', 'sample_clients', stdout=stdout, stderr=stderr)
    return {
        'statusCode': 200,
        'commands': [
            ['migrate', '--noinput'],
            ['loaddata', 'sample_clients'],
        ],
        'stdout': stdout.getvalue(),
        'stderr': stderr.getvalue(),
    }


def lambda_handler(event, context):
    return http_handler(event, context)


handler = lambda_handler
