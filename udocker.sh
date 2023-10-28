#!/bin/bash
mkdir -p /content/runtime
nohup udocker --allow-root run -p 8000:80 --volume=/content/runtime:/var/www/html/ pudding/docker-web:pwiki-20231029-0338 &