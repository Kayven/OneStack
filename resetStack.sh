#!/usr/bin/env bash
# *./resetStack.sh clear* clear the database.
# *./resetStack.sh * reset the database and create a instance.

# Hily.Hoo@gmail.com (Kayven)
# Learn more and get the most recent version at http://code.google.com/p/onestack/
set -o xtrace

if [ $1 ] && [ $1 = "clear" ]; then
	nova delete `nova list | awk 'FNR==4{print $4}'`
	MYSQL_PASSWD=${MYSQL_PASSWD:-"cloud1234"}
	NOVA_DB_USERNAME=${NOVA_DB_USERNAME:-"novadbadmin"}
	NOVA_DB_PASSWD=${NOVA_DB_PASSWD:-"cloud1234"}
	GLANCE_DB_USERNAME=${GLANCE_DB_USERNAME:-"glancedbadmin"}
	GLANCE_DB_PASSWD=${GLANCE_DB_PASSWD:-"cloud1234"}
	mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS nova;"
	mysql -uroot -p$MYSQL_PASSWD -e "CREATE DATABASE nova;"
	mysql -uroot -p$MYSQL_PASSWD -e "GRANT ALL ON nova.* TO '$NOVA_DB_USERNAME'@'%' IDENTIFIED BY '$NOVA_DB_PASSWD';"
	reboot
else
	# 5：同步数据库
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
	## 6：检查nova服务
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
	
	# ssh instance
	# ssh-keygen -f "/home/cloud/.ssh/known_hosts" -R 10.0.0.2
	# ssh -i ~/.ssh/id_rsa ubuntu@10.0.0.2
	
	## 4：开始创建虚拟机
	## nova image-list
	## nova flavor-list
	## 创建虚拟机
	# nova-manage flavor create --name=m1.minitest --memory=384 --cpu=1 --root_gb=1 --flavor=6 --ephemeral_gb=1
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
fi
