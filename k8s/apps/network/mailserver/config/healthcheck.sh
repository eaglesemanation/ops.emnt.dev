#!/bin/sh

supervisorctl status \
    changedetector clamav cron \
    dovecot fail2ban mailserver \
    postfix rspamd rspamd-redis \
    rsyslog update-check
