#!/bin/bash
## **addComputeNode.sh** is a tool to add nova-compute node to OpenStack cloud computing service.

## Hily.Hoo@gmail.com (Kayven)
## Learn more and get the most recent version at http://code.google.com/p/onestack/

set -o xtrace
## 请使用root执行本脚本！
## Ubuntu 12.04 ("Precise") 部署 OpenStack Essex，在client管理OpenStack安装nova管理工具
## 参考：
## http://docs.openstack.org/essex/openstack-compute/starter/content/


##########################################################################
## 2、自行检查下面network/interfaces的两个网卡设置
ServerControlIP="192.168.139.50"
computeControlIP="192.168.139.150"

## token, 登录dashboard密码
ADMIN_TOKEN="admin"

## network configure
NETWORK_CONF=${NETWORK_CONF:-"/etc/network/interfaces"}
cat <<INTERFACES >$NETWORK_CONF
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
pre-up ifconfig eth0 hw ether b8:ac:6f:9a:ee:e5
        address 192.168.139.51
        netmask 255.255.255.0
        network 192.168.139.0
        broadcast 192.168.139.255
        gateway 192.168.139.253
        dns-nameservers 210.72.128.8

auto br100
iface br100 inet static
    bridge_ports    eth1
    bridge_stp      off
    bridge_maxwait  0
    bridge_fd       0
    pre-up ifconfig eth1 hw ether b8:ac:6f:9a:ee:e5
        address 10.0.0.150
        netmask 255.255.255.0
        network 10.0.0.0
        broadcast 10.0.0.255
INTERFACES
sed -i -e "s/192.168.139.51/$computeControlIP/g" $NETWORK_CONF
/etc/init.d/networking restart

## 配置 /etc/nova/nova.conf，这里与控制节点的配置相同！比如ip是控制节点的ip
MYSQL_PASSWD=${MYSQL_PASSWD:-"cloud1234"}
NOVA_DB_USERNAME=${NOVA_DB_USERNAME:-"novadbadmin"}
NOVA_DB_PASSWD=${NOVA_DB_PASSWD:-"cloud1234"}

OUT_IP="192.168.139.50"
OUT_IP_PRE="192.168.139"
IN_IP="10.0.0.1"
IN_IP_PRE="10.0.0"
FLAT_IP="10.0.0.40"
FLOAT_IP="192.168.139.225"

## 选择虚拟技术，裸机使用kvm，虚拟机里面使用qemu
VIRT_TYPE="qemu"
##########################################################################

## 3、安装bridge-utils、ntp
apt-get install -y bridge-utils ntp
echo "server $ServerControlIP" > /etc/ntp.conf
service ntp restart

## 4、安装nova
apt-get install -y nova-compute

## 配置 /etc/nova/nova.conf，这里与控制节点的配置相同！比如ip是控制节点的ip
## 如果你是在虚拟机里测试Openstack。你需要把默认的虚拟化引擎从kvm改成qemu。
cat <<NOVAconf > /etc/nova/nova.conf
--dhcpbridge_flagfile=/etc/nova/nova.conf
--dhcpbridge=/usr/bin/nova-dhcpbridge
--logdir=/var/log/nova
--state_path=/var/lib/nova
--lock_path=/var/lock/nova
--allow_admin_api=true
--use_deprecated_auth=false
--auth_strategy=keystone
--scheduler_driver=nova.scheduler.simple.SimpleScheduler
--s3_host=192.168.139.50
--ec2_host=192.168.139.50
--rabbit_host=192.168.139.50
--cc_host=192.168.139.50
--nova_url=http://192.168.139.50:8774/v1.1/
--routing_source_ip=192.168.139.50
--glance_api_servers=192.168.139.50:9292
--image_service=nova.image.glance.GlanceImageService
--iscsi_ip_prefix=10.0.0
--sql_connection=mysql://novadbadmin:cloud1234@192.168.139.50/nova
--ec2_url=http://192.168.139.50:8773/services/Cloud
--keystone_ec2_url=http://192.168.139.50:5000/v2.0/ec2tokens
--api_paste_config=/etc/nova/api-paste.ini
--libvirt_type=kvm
--libvirt_use_virtio_for_bridges=true
--start_guests_on_host_boot=true
--resume_guests_state_on_host_boot=true
 
#novnc
--novnc_enabled=true
--novncproxy_base_url= http://192.168.139.50:6080/vnc_auto.html
--vncserver_proxyclient_address=192.168.139.51
--vncserver_listen=192.168.139.51

# network specific settings
--network_manager=nova.network.manager.FlatDHCPManager
--public_interface=eth0
--flat_interface=eth1
--flat_network_bridge=br100
--fixed_range=10.0.0.1/27
--floating_range=192.168.139.225/27 
--network_size=32
--flat_network_dhcp_start=10.0.0.40
--flat_injected=False
--force_dhcp_release
--iscsi_helper=tgtadm
--connection_type=libvirt
--root_helper=sudo nova-rootwrap
#--verbose
--verbose=False
NOVAconf

sed -i -e "s/novadbadmin/$NOVA_DB_USERNAME/g;s/cloud1234/$NOVA_DB_PASSWD/g" /etc/nova/nova.conf
sed -i -e "s/192.168.139.50/$OUT_IP/g;s/192.168.139.225/$FLOAT_IP/g;" /etc/nova/nova.conf
sed -i -e "s/10.0.0.1/$IN_IP/g;s/10.0.0.40/$FLAT_IP/g;s/10.0.0/$IN_IP_PRE/g;" /etc/nova/nova.conf
## kvm or qemu?
sed -i -e "s/kvm/$VIRT_TYPE/g" /etc/nova/nova.conf
sed -i -e "s/kvm/$VIRT_TYPE/g" /etc/nova/nova-compute.conf
sed -i -e "s/192.168.139.51/$computeControlIP/g;" /etc/nova/nova.conf

## 5：配置/etc/nova/api-paste.ini
sed -i -e "
       s/%SERVICE_TENANT_NAME%/admin/g;
       s/%SERVICE_USER%/admin/g;
       s/%SERVICE_PASSWORD%/$ADMIN_TOKEN/g;
    " /etc/nova/api-paste.ini
## 重启服务
service nova-compute restart

## command line:
##  nova-manage service list
