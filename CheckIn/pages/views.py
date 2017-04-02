from django.shortcuts import render
from django.http import HttpResponse
from django.template import loader

def index(request):
    template = loader.get_template('pages/index.html')
    return HttpResponse(template.render())

def qrtest(request):
    template = loader.get_template('pages/qrtest.html')
    return HttpResponse(template.render())

def signup(request):
    return HttpResponse("This is the signup view!")