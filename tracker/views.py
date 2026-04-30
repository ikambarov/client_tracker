from django.db import connection, connections, router
from django.db.models import Q
from django.db.models.functions import Length, Lower
from django.shortcuts import redirect, render
from django.views.decorators.csrf import csrf_exempt

from .models import Client

WRITE_LOAD_INSERT_SQL = """
INSERT INTO tracker_client (
    first_name,
    last_name,
    address,
    city,
    telephone
)
SELECT %s, %s, %s, %s, %s
FROM (
    SELECT
        COUNT(*) AS match_count,
        COALESCE(SUM(last_name_length), 0) AS total_name_length
    FROM (
        SELECT
            LENGTH(last_name) AS last_name_length,
            LOWER(city) AS city_lower
        FROM tracker_client
        WHERE last_name LIKE '%%son%%'
           OR city LIKE '%%ville%%'
           OR address LIKE '%%Avenue%%'
        ORDER BY
            last_name_length DESC,
            city_lower ASC,
            last_name ASC,
            first_name ASC
        LIMIT 20
    ) ranked_matches
) load_probe
"""


def show_home(request):
    return render(request,'home.html')

def find_client(request):
    last_name = request.GET.get('lastName', '').strip()
    clients = Client.objects.annotate(
        city_lower=Lower('city'),
        last_name_length=Length('last_name'),
    )

    if last_name:
        clients = clients.filter(
            Q(last_name__icontains=last_name) |
            Q(first_name__icontains=last_name) |
            Q(city__icontains=last_name) |
            Q(address__icontains=last_name)
        )
    else:
        clients = clients.filter(
            Q(last_name__icontains='son') |
            Q(city__icontains='ville') |
            Q(address__icontains='Avenue')
        ).exclude(telephone__endswith='0000')

    clients = clients.order_by(
        '-last_name_length',
        'city_lower',
        'last_name',
        'first_name',
    )[:20]

    return render(request, 'clients/findClient.html', {
        'clients': clients,
        'last_name': last_name,
    })

@csrf_exempt
def add_client(request):
    if request.method == 'POST':
        client_data = [
            request.POST.get('firstName', '').strip(),
            request.POST.get('lastName', '').strip(),
            request.POST.get('address', '').strip(),
            request.POST.get('city', '').strip(),
            request.POST.get('telephone', '').strip(),
        ]

        if not all(client_data):
            return render(request, 'clients/createOrUpdateClientForm.html', {
                'error': 'All client fields are required.',
            }, status=400)

        # Keep the inserted row unchanged while making the database do
        # extra query work before the single-row write.
        db_alias = router.db_for_write(Client)
        with connections[db_alias].cursor() as cursor:
            cursor.execute(WRITE_LOAD_INSERT_SQL, client_data)

        return redirect('find_client')

    return render(request,'clients/createOrUpdateClientForm.html')
