#!/bin/bash -v

set -ex

if [ "x$REJECT_OUTBOUND" == "xYES" ]; then
PNDA_MIRROR_IP=$(echo $PNDA_MIRROR | awk -F'[/:]' '/http:\/\//{print $4}')

# Log the global scope IP connection.
cat > /etc/rsyslog.d/10-iptables.conf <<EOF
:msg,contains,"[ipreject] " /var/log/iptables.log
STOP
EOF
sudo service rsyslog restart
iptables -F LOGGING | true
iptables -F OUTPUT | true
iptables -X LOGGING | true
iptables -N LOGGING
iptables -A OUTPUT -j LOGGING
## Accept all local scope IP packets.
  ip address show  | awk '/inet /{print $2}' | while IFS= read line; do \
iptables -A LOGGING -d  $line -j ACCEPT
  done
## Log and reject all the remaining IP connections.
iptables -A LOGGING -j LOG --log-prefix "[ipreject] " --log-level 7 -m state --state NEW
iptables -A LOGGING -d  $PNDA_MIRROR_IP/32 -j ACCEPT # PNDA mirror
if [ "x$CLIENT_IP" != "x" ]; then
iptables -A LOGGING -d  $CLIENT_IP/32 -j ACCEPT # PNDA client
fi
if [ "x$NTP_SERVERS" != "x" ]; then
NTP_SERVERS=$(echo "$NTP_SERVERS" | sed -e 's|[]"'\''\[ ]||g')
iptables -A LOGGING -d  $NTP_SERVERS -j ACCEPT # NTP server
fi
if [ "$LDAP_SERVER" != '' ]; then
iptables -A LOGGING -d  $LDAP_SERVER -j ACCEPT # LDAP server
fi
if [ "x$networkCidr" != "x" ]; then
iptables -A LOGGING -d  ${networkCidr} -j ACCEPT
fi
if [ "x$privateSubnetCidr" != "x" ]; then
iptables -A LOGGING -d  ${privateSubnetCidr} -j ACCEPT
fi
iptables -A LOGGING -j REJECT --reject-with icmp-net-unreachable
iptables-save > /etc/iptables.conf
echo -e '#!/bin/sh\niptables-restore < /etc/iptables.conf' > /etc/rc.local
chmod +x /etc/rc.d/rc.local | true
fi

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

yum install -y yum-utils yum-plugin-priorities

yum-config-manager --setopt=priority=50 --save *

[[ -n ${ADDITIONAL_REPOS} ]] && echo "${ADDITIONAL_REPOS}" > /etc/yum.repos.d/pnda.repo

# From versions.sh
export ANACONDA_VERSION="5.1.0"
export SALTSTACK_VERSION="2015.8.11"
export SALTSTACK_REPO="2015.8"
export LOGSTASH_VERSION="6.2.1"
export NODE_VERSION="6.10.2"
export JE_VERSION="5.0.73"
export CLOUDERA_MANAGER_VERSION="5.12.1"
export CLOUDERA_CDH_VERSION="5.12.1"
export CLOUDERA_CDH_PARCEL_VERSION="CDH-5.12.1-1.cdh5.12.1.p0.3"
export CLOUDERA_MANAGER_PACKAGE_VERSION="5.12.1-1.cm5121.p0.6"
export AMBARI_VERSION="2.7.0.0"
export AMBARI_PACKAGE_VERSION="2.7.0.0-897"
export AMBARI_LEGACY_VERSION="2.6.1.0"
export AMBARI_LEGACY_PACKAGE_VERSION="2.6.1.0-143"
export HDP_VERSION="2.6.5.0"
export HDP_UTILS_VERSION="1.1.0.22"

RPM_EPEL=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RPM_EPEL_KEY=https://archive.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
MY_SQL_REPO=https://repo.mysql.com/yum/mysql-5.5-community/el/7/x86_64/
MY_SQL_REPO_KEY=https://repo.mysql.com/RPM-GPG-KEY-mysql
CLOUDERA_MANAGER_REPO=http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/${CLOUDERA_MANAGER_VERSION}/
CLOUDERA_MANAGER_REPO_KEY=https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/RPM-GPG-KEY-cloudera
SALT_REPO=https://repo.saltstack.com/yum/redhat/7/x86_64/archive/${SALTSTACK_VERSION}
SALT_REPO_KEY=https://repo.saltstack.com/yum/redhat/7/x86_64/archive/${SALTSTACK_VERSION}/SALTSTACK-GPG-KEY.pub
SALT_REPO_KEY2=http://repo.saltstack.com/yum/redhat/7/x86_64/${SALTSTACK_REPO}/base/RPM-GPG-KEY-CentOS-7
[[ -z ${AMBARI_REPO} ]] && export AMBARI_REPO=http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${AMBARI_VERSION}/ambari.repo
[[ -z ${AMBARI_LEGACY_REPO} ]] && export AMBARI_LEGACY_REPO=http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/${AMBARI_LEGACY_VERSION}/ambari.repo
[[ -z ${AMBARI_REPO_KEY} ]] && export AMBARI_REPO_KEY=http://public-repo-1.hortonworks.com/ambari/centos7/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins

OFFLINE_KEYS_LIST="${PNDA_MIRROR}/mirror_rpm/RPM-GPG-KEY-EPEL-7 \
                   ${PNDA_MIRROR}/mirror_rpm/RPM-GPG-KEY-mysql \
                   ${PNDA_MIRROR}/mirror_rpm/RPM-GPG-KEY-cloudera \
                   ${PNDA_MIRROR}/mirror_rpm/SALTSTACK-GPG-KEY.pub \
                   ${PNDA_MIRROR}/mirror_rpm/RPM-GPG-KEY-CentOS-7 \
                   ${PNDA_MIRROR}/mirror_rpm/RPM-GPG-KEY-Jenkins"
if [ "x$DISTRO" == "xrhel" ]; then
  OFFLINE_KEYS_LIST="${OFFLINE_KEYS_LIST} ${PNDA_MIRROR}/mirror_rpm/RPM-GPG-KEY-redhat-release"
fi

# Guess if there is an rpm mirror
mkdir -p /tmp/reposkeys
cd /tmp/reposkeys

if ! curl -LOJf ${OFFLINE_KEYS_LIST};
then
  curl -LOJf "${RPM_EPEL_KEY}" \
	     "${MY_SQL_REPO_KEY}" \
	     "${CLOUDERA_MANAGER_REPO_KEY}" \
	     "${SALT_REPO_KEY}" \
	     "${SALT_REPO_KEY2}" \
	     "${AMBARI_REPO_KEY}"

  RPM_EXTRAS=$RPM_EXTRAS_REPO_NAME
  RPM_OPTIONAL=$RPM_OPTIONAL_REPO_NAME
  yum-config-manager --setopt=priority=50 --save --enable $RPM_EXTRAS $RPM_OPTIONAL
  yum-config-manager --setopt=priority=50 --save --add-repo $MY_SQL_REPO
  yum-config-manager --setopt=priority=50 --save --add-repo $CLOUDERA_MANAGER_REPO
  yum-config-manager --setopt=priority=50 --save --add-repo $SALT_REPO
  yum-config-manager --setopt=priority=50 --save --add-repo $AMBARI_REPO
  curl -LJ -o /etc/yum.repos.d/ambari-legacy.repo $AMBARI_LEGACY_REPO
  yum install -y $RPM_EPEL || true
  yum-config-manager --setopt=priority=50 --save "*epel*
fi
rpm --import *

yum install -y deltarpm

PIP_INDEX_URL="$PNDA_MIRROR/mirror_python/simple"
TRUSTED_HOST=$(echo $PIP_INDEX_URL | awk -F'[/:]' '/http:\/\//{print $4}')
cat << EOF > /etc/pip.conf
[global]
index-url=$PIP_INDEX_URL
trusted-host=$TRUSTED_HOST
EOF
cat << EOF > /root/.pydistutils.cfg
[easy_install]
index_url=$PIP_INDEX_URL
EOF
