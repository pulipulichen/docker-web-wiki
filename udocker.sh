#!/bin/bash
udocker run -p 8000:80 --volume=./runtime:/var/www/html/ pudding/docker-web:pwiki-20231029-0259
