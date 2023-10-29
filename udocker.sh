#!/bin/bash

# 使用說明
# - 對外port必須是8000
# - 如用到目錄，必須事前建立
# - 目錄路徑必須是完整路徑

mkdir -p /content/docker-web-wiki
nohup udocker --allow-root run -p 8000:80 --volume=/content/docker-web-wiki:/var/www/html/ pudding/docker-web:pwiki-20231029-0338 > .nohup.out 2>&1 &


