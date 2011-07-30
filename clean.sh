#!/bin/sh
rm -r node_modules
rm app.js
rm -r lib
rm public/javascripts/diali.js
find public/stylesheets -name '*.css' -a ! -name 'jquery-ui-*' -exec rm {} \;
