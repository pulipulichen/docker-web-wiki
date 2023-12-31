FROM php:8.3.0RC5-apache-bookworm

#RUN sed -i '/jessie-updates/d' /etc/apt/sources.list

RUN apt-get update
RUN apt-get install -y wget nano curl wget rsync

RUN mkdir -p /docker-build/
RUN mkdir -p /app/
COPY ./docker-build/app /docker-build/app
COPY ./docker-build/startup.sh /startup.sh

ENV LOCAL_VOLUMN_PATH=/var/www/html/
ENV SHARED_PATH=/var/www/html/.pwiki_data/
ENV LOCAL_PORT=80

ENTRYPOINT []
CMD ["bash", "/startup.sh"]