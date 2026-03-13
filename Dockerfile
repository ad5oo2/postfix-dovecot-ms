FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
  git \
  syslog-ng \
  locales \
  cron \
  python3-mysql.connector \
  fail2ban \
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

VOLUME ["/var/mail/vhosts", "/var/lib/fail2ban", "/var/log/external"]

EXPOSE 25 465 587 993 995

COPY ./start.sh /start.sh

ENTRYPOINT [ "/start.sh" ]
