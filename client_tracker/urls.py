"""client_tracker URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf import settings
from django.contrib import admin
from django.http import FileResponse
from django.urls import include, path


def static_root_file(relative_path, content_type):
    file_path = settings.BASE_DIR / 'static' / relative_path
    return FileResponse(file_path.open('rb'), content_type=content_type)


def favicon(request):
    return static_root_file('images/django_icon.png', 'image/png')


def robots_txt(request):
    return static_root_file('robots.txt', 'text/plain')

urlpatterns = [
    path('favicon.ico', favicon, name='favicon'),
    path('robots.txt', robots_txt, name='robots_txt'),
    path('', include('tracker.urls')),
    path('admin/', admin.site.urls),
]
