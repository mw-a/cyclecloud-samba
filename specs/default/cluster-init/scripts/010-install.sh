#!/bin/bash

set -e

# for now we assume the machine uses adauth - traditional net ads join would be
# possible as well of course
AD_JOIN=$(jetpack config adauth.ad_join "")
AD_DOMAIN=$(jetpack config adauth.ad_domain "")

[ "$AD_JOIN" = True -a -n "$AD_DOMAIN" ] || exit 0

NETBIOS_DOMAIN=$(jetpack config samba.netbios_domain "")
if [ -z "$NETBIOS_DOMAIN" ] ; then
       NETBIOS_DOMAIN=${AD_DOMAIN%%.*}
       NETBIOS_DOMAIN=${NETBIOS_DOMAIN^^}
fi

dnf install -y samba samba-winbind sssd-winbind-idmap samba-client tdb-tools

# init secrets.tdb with dummy data so that net changesecretpw is happy
tdbtool /var/lib/samba/private/secrets.tdb create foo
tdbtool /var/lib/samba/private/secrets.tdb store SECRETS/MACHINE_LAST_CHANGE_TIME/$NETBIOS_DOMAIN '\A5\00\00\00'
tdbtool /var/lib/samba/private/secrets.tdb store SECRETS/MACHINE_PASSWORD/$NETBIOS_DOMAIN 'foo\00'

# update machine passwort and sync with secrets.tdb in one go
adcli update --verbose --add-samba-data --computer-password-lifetime=0 -D "$AD_DOMAIN"

# no frills here (yet) - just provide the whole config from jetpack
jetpack config samba.smb_conf > /etc/samba/smb.conf

systemctl start smb winbind
