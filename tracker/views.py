from django.shortcuts import render
from django.http import HttpResponse

# Create your views here.

def show_home(request):
    return render(request,'home.html')

def find_client(request):
    return render(request,'clients/findClient.html')

def add_client(request):
    return render(request,'clients/createOrUpdateClientForm.html')