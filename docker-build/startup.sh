#!/bin/bash

rsync --ignore-existing -r /docker-build/app/ /var/www/html/
chmod -R 777 /var/www/html/.pwiki_data/*

docker-php-entrypoint apache2-foreground