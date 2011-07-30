Dia.li (fe) log
===============

Diali is a website to log daily life activities.

Installation
------------

    $ find -name '*.coffee' -exec sed -i 's/beta.dia.li/<DOMAIN>/' {} \;
    $ find -name '*.coffee' -exec sed -i 's/3000/<NODE_PORT>/' {} \;
    $ find -name '*.coffee' -exec sed -i 's/9000/<WEB_SOCKET_PORT>/' {} \;
    $ npm install .

Usage
-----

    $ redis-server & 
    $ NODE_ENV=production node app.js &

    $ curl http://<DOMAIN>:<NODE_PORT>
