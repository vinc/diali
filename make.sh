#!/bin/sh
coffee -c app.coffee
coffee -o lib/ -c src/server
coffee -o public/javascripts -c src/client
compass compile
