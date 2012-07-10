#!/bin/bash
## If you don't want to uninstall all softs, please excute only ./delStack.sh

set -o xtrace

## uninstall OpenStack and mysql
apt-get remove -y keystone python-keystone python-keystoneclient \
	 glance glance-api glance-client glance-common glance-registry python-glance \
	 nova-api nova-cert nova-common nova-compute nova-compute-kvm nova-doc nova-network nova-objectstore nova-scheduler  nova-volume python-nova python-novaclient  nova-consoleauth python-novnc novnc \
	 libapache2-mod-wsgi openstack-dashboard \
	mysql-server python-mysqldb phpmyadmin

## uninstall other tools
apt-get remove -y bridge-utils ntp \
	 tgt curl expect \
	 open-iscsi open-iscsi-utils \
	 rabbitmq-server memcached python-memcache \
	 kvm libvirt-bin qemu qemu-kvm

## clean cache
apt-get clean
apt-get autoclean
## You'd better reboot it.
