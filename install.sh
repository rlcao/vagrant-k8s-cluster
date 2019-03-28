#!/usr/bin/env bash
# change time zone
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
timedatectl set-timezone Asia/Shanghai
# setup yum proxy
#rm /etc/yum.repos.d/CentOS-Base.repo
cp /vagrant/yum/kubernetes.repo /etc/yum.repos.d/
sed -i 's,proxy=_none_,proxy=http://148.87.19.20:80,' /etc/yum.conf

#mv /etc/yum.repos.d/CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
# using socat to port forward in helm tiller
# install  kmod and ceph-common for rook
yum install -y wget curl conntrack-tools vim net-tools telnet tcpdump bind-utils socat ntp kmod ceph-common dos2unix
kubernetes_release="/vagrant/kubernetes-server-linux-amd64.tar.gz"
# Download Kubernetes
#if [[ $(hostname) == "node1" ]] && [[ ! -f "$kubernetes_release" ]]; then
    #wget https://storage.googleapis.com/kubernetes-release/release/v1.14.0/kubernetes-server-linux-amd64.tar.gz -P /vagrant/
#fi

# enable ntp to sync time
echo 'sync time'
systemctl start ntpd
systemctl enable ntpd
echo 'disable selinux'
setenforce 0
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config

echo 'enable iptable kernel parameter'
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl -p

echo 'set host name resolution'
cat >> /etc/hosts <<EOF
172.17.8.101 node1
172.17.8.102 node2
172.17.8.103 node3
EOF

cat /etc/hosts

#echo 'set nameserver'
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 206.223.27.1" >> /etc/resolv.conf
echo "nameserver 206.223.27.2" >> /etc/resolv.conf
cat /etc/resolv.conf

echo 'disable swap'
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

#create group if not exists
egrep "^docker" /etc/group >& /dev/null
if [ $? -ne 0 ]
then
  groupadd docker
fi

usermod -aG docker vagrant
rm -rf ~/.docker/
yum --disablerepo=kubernetes install -y docker.x86_64
# To fix docker exec error, downgrade docker version, see https://github.com/openshift/origin/issues/21590
#yum downgrade -y docker-1.13.1-75.git8633870.el7.centos.x86_64 docker-client-1.13.1-75.git8633870.el7.centos.x86_64 docker-common-1.13.1-75.git8633870.el7.centos.x86_64

yum --disablerepo=* --enablerepo=kubernetes install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

#kubelet requirements
cat <<EOF>/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF 
sysctl --system
modprobe br_netfilter

mkdir /etc/systemd/system/docker.service.d
cat <<EOF>/etc/systemd/system/docker.service.d/http_proxy.conf
[Service]
Environment="HTTP_PROXY=http://148.87.19.20:80"
EOF

systemctl enable docker.service
systemctl enable --now kubelet.service
systemctl start docker.service
