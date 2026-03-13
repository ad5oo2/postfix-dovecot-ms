FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
  git \
  rsyslog \
  locales \
  cron \
  pip \
  opendkim \
  opendkim-tools \
  iptables \
  postfix \
  postfix-mysql \
  dovecot-core \
  dovecot-imapd \
  dovecot-lmtpd \
  dovecot-mysql \
  dovecot-pop3d

RUN pip install mysql-connector-python --break-system-packages

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN mkdir -p /var/mail/vhosts && \
  groupadd -g 5000 vmail && \
  useradd -g vmail -u 5000 vmail -d /var/mail && \
  chown -R vmail:vmail /var/mail

RUN mkdir -p /etc/letsencrypt/live && \
  chmod 700 /etc/letsencrypt/live && \
  mkdir -p /etc/opendkim/keys

VOLUME ["/var/mail/vhosts", "/var/log/external"]

EXPOSE 25 465 587 993 995

COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/app/start.sh" ]
