#!/usr/bin/env bash
# **oneStack.sh** is a tool to deploy complete and real OpenStack cloud computing service.

# This script installs and configures various combinations of *Glance*,
# *Horizon*, *Keystone*, *Nova*, *Mysql* and others.

# Hily.Hoo@gmail.com (Kayven)
# Learn more and get the most recent version at http://code.google.com/p/onestack/

set -o xtrace
## 请使用root执行本脚本！
## Ubuntu 12.04 ("Precise") 部署 OpenStack Essex（或者ubuntu11.10版本）
## 参考：
## http://hi.baidu.com/chenshake/item/29a7b8c1b96fb82d46d5c0fb
## http://docs.openstack.org/essex/openstack-compute/starter/content/

## 一：准备系统
## 1：下载ubuntu 12.04. 服务器版本
## http://mirrors.ustc.edu.cn/ubuntu-releases/12.04/ubuntu-12.04-server-amd64.iso
## 2：安装OS
## 最小化安装，只需要安装ssh server就可以。
## 装完系统后 更新源里的包,更新系统。确保你装的是最新版本的包。

## 3：设置root权限
## 为了简单，全部都是用root来运行。
if [ `whoami` != "root" ]; then
	sudo passwd
	exec su -c 'sh ./oneStack.sh'
fi

## 4：设置参数和环境配置，直到两行#号结束
## 这个配置以后就不需要更改了，比如看到192.168.139.50等ip，不用更改，脚本会自动替换这些初始值。
## 可以变动的是，第500行的image的下载；或者去掉第七步开始的部分（上传镜像，创建实例）
##########################################################################
##########################################################################
## 如果原来安装过OpenStack，请先执行 ./delStack.sh
## 1）配置参数
## 数据库相关
MYSQL_PASSWD=${MYSQL_PASSWD:-"cloud1234"}
NOVA_DB_USERNAME=${NOVA_DB_USERNAME:-"novadbadmin"}
NOVA_DB_PASSWD=${NOVA_DB_PASSWD:-"cloud1234"}
GLANCE_DB_USERNAME=${GLANCE_DB_USERNAME:-"glancedbadmin"}
GLANCE_DB_PASSWD=${GLANCE_DB_PASSWD:-"cloud1234"}

## 注意：单网卡的去掉interfaces的eth1，并把nova.conf里面eth1改完eth0即可！
## 自行检查下面network/interfaces的两个网卡设置
## 本机器外网ip （包括局域网的内网ip，相对于OpenStack内网而言的）
OUT_IP="192.168.139.50"
OUT_IP_PRE="192.168.139"
## nova-network内网ip
IN_IP="10.0.0.1"
IN_IP_PRE="10.0.0"
## flat的起始ip
FLAT_IP="10.0.0.40"
## 浮动ip的起始值
FLOAT_IP="192.168.139.225"

## 选择虚拟技术，裸机使用kvm，虚拟机里面使用qemu
VIRT_TYPE="qemu"
## token, 登录dashboard密码（用户名admin）
ADMIN_TOKEN="admin"
##########################################################################
## 2）检查系统是否ubuntu12.04，据反映11.10也可以正常安装，可以去掉这一段检查
# Determine what system we are running on.  This provides ``os_VENDOR``...
# Determine OS Vendor, Release and Update 
#if [[ -x "`which lsb_release 2>/dev/null`" ]]; then
    os_VENDOR=$(lsb_release -i -s)
    os_RELEASE=$(lsb_release -r -s)
    os_UPDATE=""
    os_CODENAME=$(lsb_release -c -s)
#fi
if [ "Ubuntu" = "$os_VENDOR" ]; then
    DISTRO=$os_CODENAME
else
    echo "The os didn't seems to be Ubuntu."
    exit 1
fi
echo $DISTRO
if [ "precise" != ${DISTRO} -a "oneiric" != ${DISTRO} ]; then
    echo "WARNING: this script has been tested on oneiric or precise"
    exit 1
fi

############################################################################
## 3）以下系统配置，语言中文支持、国内APT源、网络设置（两个网卡），可以自行配置，注释掉这些步骤。
## locale
cat <<EOF >/var/lib/locales/supported.d/local
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_CN.GBK GBK
EOF
sed -i -e 's/zh_CN:UTF-8/en_US:UTF-8/g' /etc/default/locale
sed -i -e 's/zh_CN:zh/en_US:en/g' /etc/default/locale
dpkg-reconfigure locales
locale-gen
############################################################################
## 4：设置网络
SOURCE_FILE=${SOURCE_FILE:-"/etc/apt/sources.list"}
cp $SOURCE_FILE $SOURCE_FILE.bak
cat <<APT >$SOURCE_FILE
deb http://debian.ustc.edu.cn/ubuntu/ precise main restricted universe multiverse
deb http://debian.ustc.edu.cn/ubuntu/ precise-backports restricted universe multiverse
deb http://debian.ustc.edu.cn/ubuntu/ precise-proposed main restricted universe multiverse
deb http://debian.ustc.edu.cn/ubuntu/ precise-security main restricted universe multiverse
deb http://debian.ustc.edu.cn/ubuntu/ precise-updates main restricted universe multiverse
deb-src http://debian.ustc.edu.cn/ubuntu/ precise main restricted universe multiverse
deb-src http://debian.ustc.edu.cn/ubuntu/ precise-backports main restricted universe multiverse
deb-src http://debian.ustc.edu.cn/ubuntu/ precise-proposed main restricted universe multiverse
deb-src http://debian.ustc.edu.cn/ubuntu/ precise-security main restricted universe multiverse
deb-src http://debian.ustc.edu.cn/ubuntu/ precise-updates main restricted universe multiverse
APT
#sed -i 's/debian.ustc.edu.cn/mirrors.163.com/g' $SOURCE_FILE

# network configure
NETWORK_CONF=${NETWORK_CONF:-"/etc/network/interfaces"}
if ! grep -q eth1 $NETWORK_CONF; then
	cat <<INTERFACES >$NETWORK_CONF
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
pre-up ifconfig eth0 hw ether b8:ac:6f:9a:ee:e4
        address 192.168.139.50
        netmask 255.255.255.0
        network 192.168.139.0
        broadcast 192.168.139.255
        gateway 192.168.139.253
        dns-nameservers 210.72.128.8

auto eth1
iface eth1 inet static
pre-up ifconfig eth1 hw ether b8:ac:6f:9a:ee:e4
        address 10.0.0.1
        netmask 255.255.255.0
        network 10.0.0.0
        broadcast 10.0.0.255
INTERFACES
        /etc/init.d/networking restart
fi
## 以上系统配置，可以自行配置，注释掉这些步骤。
############################################################################
############################################################################

apt-get update



## 5：安装bridge
apt-get install -y bridge-utils
## 6：设置NTP
apt-get install -y ntp
if ! grep -q fudge "/etc/ntp.conf"; then
	cat <<NTPconf > /etc/ntp.conf
server ntp.ubuntu.com iburst
server 127.127.1.0
fudge 127.127.1.0 stratum 10
NTPconf
fi
service ntp restart
## 7：设置Iscsi
apt-get install -y tgt ssh w3m unzip wget curl expect
## 安装iscsi客户端、安装rabbitmq
apt-get install -y open-iscsi open-iscsi-utils
apt-get install -y rabbitmq-server memcached python-memcache
apt-get install -y kvm libvirt-bin qemu qemu-kvm

## 二：安装mysql和创建相关数据库
## Openstack的组件：nova，keystone，glance，都需要数据库。不过目前官方建议keystone，采用sqlite存储，而不用mysql存放。所以我们只需要创建nova和glance两个数据库就可以。
## 1：安装mysql
## 过程中，会提示你输入root密码。通过debconf-set-selections读取跳过这一步.
#MYSQL_PASSWD=${MYSQL_PASSWD:-"cloud1234"}
## apt-get install debconf debconf-utils
cat <<MYSQL_PRESEED | debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PASSWD
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PASSWD
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

apt-get install --no-install-recommends -y mysql-server python-mysqldb
## chkconfig mysql on
## 让mysql支持外部访问
sed -i '/^bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf  
service mysql restart
if [ ! -s /etc/apache2/httpd.conf ]; then
        echo "ServerName localhost" >> /etc/apache2/httpd.conf
        /etc/init.d/apache2 restart
fi

## 2：安装phpmyadmin （可选）
cat <<PHPmyadmin | debconf-set-selections
phpmyadmin phpmyadmin/reconfigure-webserver  text     apache2
phpmyadmin phpmyadmin/dbconfig-install       boolean  true
phpmyadmin phpmyadmin/app-password-confirm   password $MYSQL_PASSWD
phpmyadmin phpmyadmin/mysql/admin-pass       password $MYSQL_PASSWD
phpmyadmin phpmyadmin/password-confirm       password $MYSQL_PASSWD
phpmyadmin phpmyadmin/setup-password         password $MYSQL_PASSWD
phpmyadmin phpmyadmin/mysql/app-pass         password $MYSQL_PASSWD
PHPmyadmin
apt-get --no-install-recommends -yq install phpmyadmin

## 3：创建数据库
## nova数据库，   管理员：novadbadmin，密码是：cloud1234
## glance数据库，管理员：glancedbadmin，密码是：cloud1234
## 如果你修改密码，后面很多配置都需要相应更改。
##   mysql -uroot -p
##   CREATE DATABASE nova;
##   GRANT ALL PRIVILEGES ON nova.* TO 'novadbadmin'@'%' IDENTIFIED BY 'cloud1234';
##   CREATE DATABASE glance;
##   GRANT ALL PRIVILEGES ON glance.* TO 'glancedbadmin'@'%' IDENTIFIED BY 'cloud1234';
##   quit
mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS nova;"
mysql -uroot -p$MYSQL_PASSWD -e "CREATE DATABASE nova;"
mysql -uroot -p$MYSQL_PASSWD -e "GRANT ALL ON nova.* TO '$NOVA_DB_USERNAME'@'%' IDENTIFIED BY '$NOVA_DB_PASSWD';"
mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS glance;"
mysql -uroot -p$MYSQL_PASSWD -e "CREATE DATABASE glance;"
mysql -uroot -p$MYSQL_PASSWD -e "GRANT ALL ON glance.* TO '$GLANCE_DB_USERNAME'@'%' IDENTIFIED BY '$GLANCE_DB_PASSWD';"
if [ -e /var/lib/keystone/keystone.db ]; then
rm -rf /var/lib/keystone/keystone.db
fi

## 三：安装和配置keystone
## Openstack的各个组件，keystone是最难配置。搞定keystone，后面应该就没啥麻烦。
## 1：安装keystone
apt-get install -y keystone python-keystone python-keystoneclient
## 2：配置keystone
## 如果更改token，需要修改 /etc/keystone/keystone.conf 两个地方
##    默认定义的token就是ADMIN，web登录admin就是这个密码
##    [DEFAULT]
##    bind_host = 0.0.0.0
##    public_port = 5000
##    admin_port = 35357
##    admin_token = ADMIN
##    另外一个地方是
##    [catalog]
##    #driver = keystone.catalog.backends.sql.Catalog
##    driver = keystone.catalog.backends.templated.TemplatedCatalog
##    template_file = /etc/keystone/default_catalog.templates
##     
sed -i -e 's/keystone.catalog.backends.sql.Catalog/keystone.catalog.backends.templated.TemplatedCatalog\ntemplate_file = \/etc\/keystone\/default_catalog.templates/g' /etc/keystone/keystone.conf
sed -i -e "s/ADMIN/$ADMIN_TOKEN/g" /etc/keystone/keystone.conf
service keystone restart

## 3: 导入数据
## 这个比较有技术含量。通过修改devstack的keystone_data.sh 脚本。实现导入数据。如果你上面的设置都和我一样，那么其实直接运行这个脚本就可以。
## wget http://www.hastexo.com/system/files/user/4/keystone_data.sh_.txt -O keystone_data.sh
wget http://onestack.googlecode.com/files/gen_keystone_data.sh -O gen_keystone_data.sh
chmod +x gen_keystone_data.sh
## 运行脚本, 如果你修改的默认的用户名和密码，你需要修改脚本。修改两个地方
## 第一个是登录dashboard的admin的密码
## 第二个就是keystone的token
## #ADMIN_PASSWORD=${ADMIN_PASSWORD:-hastexo}
## ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
## SERVICE_PASSWORD=${SERVICE_PASSWORD:-$ADMIN_PASSWORD}
## #export SERVICE_TOKEN="hastexo"
## export SERVICE_TOKEN="Centrin"
## export SERVICE_ENDPOINT="http://localhost:35357/v2.0"
## SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}
sed -i -e "s/hastexo/$ADMIN_TOKEN/g" gen_keystone_data.sh 
 
./gen_keystone_data.sh
##  顺利运行，会什么都没有输出
##  #echo $?
##  下面会输出0 ，表示正常。你就别再运行脚本
##  keystone --tenant=admin --username=admin --password=hastexo  --auth_url=http://127.0.0.1:5000/v2.0 user-list
##  看到这些，就说明keystone安装正常。

cat <<ENV_AUTH >> /etc/profile
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN
export OS_AUTH_URL="http://localhost:5000/v2.0/"
ENV_AUTH
sed -i -e "s/ADMIN/$ADMIN_TOKEN/g" /etc/profile
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_TOKEN
export OS_AUTH_URL="http://localhost:5000/v2.0/"
#source /etc/profile
## 检查检查
## # export | grep OS_
## declare -x OS_AUTH_URL="http://localhost:5000/v2.0/"
## declare -x OS_PASSWORD="hastexo"
## declare -x OS_TENANT_NAME="admin"
## declare -x OS_USERNAME="admin"
## 这个时候，直接运行
## root@node6:~# keystone user-list


## 四：安装和配置glance
## 1：安装软件
apt-get install -y glance glance-api glance-client glance-common glance-registry python-glance
## 2：配置/etc/glance/glance-api-paste.ini 
## 修改文件最后3行，这些设置都是keystone导入数据的时候设置的。
sed -i -e "
       s/%SERVICE_TENANT_NAME%/admin/g;
       s/%SERVICE_USER%/admin/g;
       s/%SERVICE_PASSWORD%/$ADMIN_TOKEN/g;
    " /etc/glance/glance-api-paste.ini
 
## 3：设置 /etc/glance/glance-registry-paste.ini
sed -i -e "
       s/%SERVICE_TENANT_NAME%/admin/g;
       s/%SERVICE_USER%/admin/g;
       s/%SERVICE_PASSWORD%/$ADMIN_TOKEN/g;
    " /etc/glance/glance-registry-paste.ini
## 4：配置/etc/glance/glance-registry.conf
## 修改
## #sql_connection = sqlite:////var/lib/glance/glance.sqlite
## sql_connection = mysql://glancedbadmin:ohC3teiv@10.42.0.6/glance
## 在末尾添加两行
## [paste_deploy]
## flavor = keystone
GLANCE_API_CONF=${GLANCE_API_CONF:-"/etc/glance/glance-api.conf"}
GLANCE_REGISTRY_CONF=${GLANCE_REGISTRY_CONF:-"/etc/glance/glance-registry.conf"}
PUBLIC_IP=${PUBLIC_IP:-"192.168.139.50"}
sed -i '/sql_connection = .*/{s|sqlite:///.*|mysql://'"$GLANCE_DB_USERNAME"':'"$GLANCE_DB_PASSWD"'@'"$PUBLIC_IP"'/glance|g}' $GLANCE_API_CONF
cat <<EOF >>$GLANCE_API_CONF
[paste_deploy]
flavor = keystone
EOF
sed -i '/sql_connection = .*/{s|sqlite:///.*|mysql://'"$GLANCE_DB_USERNAME"':'"$GLANCE_DB_PASSWD"'@'"$PUBLIC_IP"'/glance|g}' $GLANCE_REGISTRY_CONF
cat <<EOF >>$GLANCE_REGISTRY_CONF
[paste_deploy]
flavor = keystone
EOF

## 5：配置/etc/glance/glance-api.conf
## 6：同步数据库
glance-manage version_control 0
glance-manage db_sync          
service glance-api restart && service glance-registry restart

## 7：验证glance服务是否正常
# glance index
## 没有任何的输出。表示正常。
## #echo $?
## 下面会输出0 ，表示正常。
## # glance --version
## glance 2012.1

## 8：下载镜像并上传
## ubuntu官方专门提供image，http://uec-images.ubuntu.com。不过一定要注意
## 这些镜像，都是必须使用密钥登录，直接用用户名密码是无法的登录的。
## 下载镜像
## http://cloud-images.ubuntu.com/precise/current/
## 这应该是ubuntu提供的最新的稳定的镜像。
#wget http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img
##  expect -c "spawn /usr/bin/scp  yuan@192.168.139.84:/home/yuan/precise-server-cloudimg-amd64-disk1.img .; expect {
##     \"password:\"; {
##    send \"yyhu\r\n\";
##    }; \"Are you sure you want to continue connecting (yes/no)?\" {
##    send \"yes\r\n\" ;
##    expect \"password:\";
##    send \"yyhu\r\n\";
##    }
##  } ; set timeout -1; expect -re \"100%\";"
##^^####sleep 5; expect -re \"password\"; send \"yyhu\r\n\";


# glance add name="Ubuntu12.04-amd64" is_public=true container_format=ovf disk_format=qcow2 < precise-server-cloudimg-amd64-disk1.img
## 这里还有一种方法上传，如果你没用环境变量。
## glance --tenant=admin--username=admin --password=hastexo  --auth_url=http://127.0.0.1:5000/v2.0 add name="Ubuntu 11.10 cloudimg amd64" is_public=true container_format=ovf disk_format=qcow2 < /root/precise-server-cloudimg-amd64-disk1.img
## 上传完镜像后。在运行
## glance index


## 五：安装配置nova
## 1:安装nova相关组件
apt-get install -y nova-api nova-cert nova-common nova-compute nova-compute-kvm nova-doc nova-network nova-objectstore nova-scheduler  nova-volume python-nova python-novaclient  nova-consoleauth python-novnc novnc
## 2：配置 /etc/nova/nova.conf
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
--vncserver_proxyclient_address=127.0.0.1
--vncserver_listen=127.0.0.1

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
## if ! kvm-ok 1>/dev/null 2>&1; then
## 	sed -i -e "s/kvm/qemu/" /etc/nova/nova-compute.conf
## fi

sed -i -e "s/novadbadmin/$NOVA_DB_USERNAME/g;s/cloud1234/$NOVA_DB_PASSWD/g" /etc/nova/nova.conf
sed -i -e "s/192.168.139.50/$OUT_IP/g;s/192.168.139.225/$FLOAT_IP/g;" /etc/nova/nova.conf
sed -i -e "s/10.0.0.1/$IN_IP/g;s/10.0.0.40/$FLAT_IP/g;s/10.0.0/$IN_IP_PRE/g;" /etc/nova/nova.conf
## kvm or qemu?
sed -i -e "s/kvm/$VIRT_TYPE/g" /etc/nova/nova.conf
sed -i -e "s/kvm/$VIRT_TYPE/g" /etc/nova/nova-compute.conf

## 3：配置/etc/nova/api-paste.ini
sed -i -e "
       s/%SERVICE_TENANT_NAME%/admin/g;
       s/%SERVICE_USER%/admin/g;
       s/%SERVICE_PASSWORD%/$ADMIN_TOKEN/g;
    " /etc/nova/api-paste.ini
# 4：停止和重启nova相关服务

## 更改卷组，否则启动nova-volume会出错。
vgrename `hostname` nova-volumes
## 设置ipv4转发，否则外面能连接虚拟机，虚拟机访问不了外面
sysctl -w net.ipv4.ip_forward=1
##or:
##echo 1 > /proc/sys/net/ipv4/ip_forward

for a in libvirt-bin nova-network nova-compute nova-api nova-objectstore nova-scheduler novnc nova-volume nova-consoleauth; do service "$a" restart; done



## 六：安装和配置Dashbaord
## 1：安装dashbaord
apt-get install -y libapache2-mod-wsgi openstack-dashboard
/etc/init.d/apache2 restart

## 这个时候，你就可以登录dashboard
## http://192.168.139.50
## user:admin
## pass:ADMIN
## 之后通过前端web管理


## 七：创建第一个VM，可以通过上面安装的web管理系统创建。

# 0：同步数据库
## 以前我运行同步数据库，如果正确, 当nova.conf
## --verbose=False
## 是没有任何的输出，否则有一堆是输出。
nova-manage db sync

# 创建网络
nova-manage network create private --fixed_range_v4=10.0.0.1/27 --num_networks=1 --bridge=br100 --bridge_interface=eth1 --network_size=32

## 设定floating IP
nova-manage floating create --ip_range=192.168.139.225/27

## 设置权限
chown -R nova:nova /etc/nova
## 再重启相关服务
for a in libvirt-bin nova-network nova-compute nova-api nova-objectstore nova-scheduler novnc nova-volume nova-consoleauth; do service "$a" restart; done
sleep 10
 
## 1：检查nova服务
## 一路回车，就可以了。通过expect可以不用输入。
if [ ! -e ~/.ssh/id_rsa ]; then
expect -c "spawn ssh-keygen ; set timeout 5; expect \":\"; send \"\r\n\"; set timeout 3; expect  \":\"; send \"\r\n\";set timeout 3; expect \":\"; send \"\r\n\"; expect eof;"
fi
## 2：上传密钥到数据库
nova keypair-add --pub_key ~/.ssh/id_rsa.pub key1
## nova keypair-list


## 打开防火墙
nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0


## 4：开始创建虚拟机
## nova image-list
## nova flavor-list
## 创建虚拟机
# nova-manage flavor create --name=m1.minitest --memory=384 --cpu=1 --root_gb=1 --flavor=6 --ephemeral_gb=1

## 上面的下载镜像移到这一步，可以去掉以下的步骤
wget http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img
glance add name="Ubuntu12.04-amd64" is_public=true container_format=ovf disk_format=qcow2 < precise-server-cloudimg-amd64-disk1.img
nova boot --flavor 1 --image "Ubuntu12.04-amd64" --key_name key1 cloud01
# nova show cloud01
# nova console-log cloud01

##关联vm
sleep 10
## nova floating-ip-create
## nova add-floating-ip cloud01 192.168.139.226
nova show cloud01
nova add-floating-ip cloud01 `nova floating-ip-create | awk 'FNR==4{print $2}'`
nova list
nova show cloud01
# ssh instance
# ssh-keygen -f "/home/cloud/.ssh/known_hosts" -R 10.0.0.2
# ssh -i ~/.ssh/id_rsa ubuntu@10.0.0.2

## 5.有用的命令
### 查看keypair
### nova keypair-list
### 删除keypair
### nova keypair-delete
### 查看vm
### nova list
### 删除vm，vm的ID
### nova delete 10d1bc19-b2c4-4eee-a5c8-b256bda3f343

## 八、完成安装部署
cat <<EOF >&1
 1. login the dashboard
   http://192.168.139.50
   user:admin
   pass:admin or $ADMIN_TOKEN
 2. login a instance("cloud01")
   ssh -i ~/.ssh/id_rsa ubuntu@10.0.0.2
 3. view & manage
   nova list
   nova show cloud01
   ...
 4. enjoy yourself! (Contact Hily.Hoo@gmail.com)
EOF
