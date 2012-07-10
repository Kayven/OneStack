#!/usr/bin/env bash
# This script deletes three main OpenStack tools.
# You can add others youself.

# Hily.Hoo@gmail.com (Kayven)
# Learn more and get the most recent version at http://code.google.com/p/onestack/

set -o xtrace

## 
apt-get remove -y keystone python-keystone python-keystoneclient
apt-get remove -y glance glance-api glance-client glance-common glance-registry python-glance
apt-get remove -y nova-api nova-cert nova-common nova-compute nova-compute-kvm nova-doc nova-network nova-objectstore nova-scheduler  nova-volume python-nova python-novaclient  nova-consoleauth python-novnc novnc
apt-get remove -y libapache2-mod-wsgi openstack-dashboard

## mysql
MYSQL_PASSWD=${MYSQL_PASSWD:-"cloud1234"}
mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS nova;"
mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS glance;"
mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS keystone;"
#apt-get update
dpkg -l |grep keystone|awk '{print $2}'|xargs dpkg -P
dpkg -l |grep glance|awk '{print $2}'|xargs dpkg -P
dpkg -l |grep nova|awk '{print $2}'|xargs dpkg -P
