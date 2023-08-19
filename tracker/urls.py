from django.urls import path
from . import views

urlpatterns = [
    path('',views.show_home, name='home'),
    path('find_client',views.find_client,name='find_client'),
    path('add_client',views.add_client,name='add_client')
]