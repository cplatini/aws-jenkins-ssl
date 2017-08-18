#!/bin/bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
setenforce 0
service iptables stop
service ip6tables stop


yum -y install wget
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key

amicheck=`grep Amazon /etc/issue`
rhelbase=`grep Red /etc/redhat-release`
centosbase=`grep CentOS /etc/redhat-release`
rhelrelease=`cat /etc/redhat-release | awk '{print $7}' | cut -d. -f1`
centosrelease=`cat /etc/redhat-release | awk '{print $4}' | cut -d. -f1`

if [ "$rhelbase" != "" ];then
	base="rhel"
	release=$rhelrelease
elif [ "$centosbase" != "" ];then
	base="centos"
	release=$centosrelease
fi

if [ "$amicheck" = "" ];then
	rpm -Uvh http://nginx.org/packages/$base/$release/noarch/RPMS/nginx-release-$base-$release-0.el$release.ngx.noarch.rpm
	yum -y install jenkins java nginx
else
	yum -y remove java-1.7.0-openjdk.x86_64
	yum -y install java-1.8.0-openjdk.x86_64
	yum -y install jenkins nginx
fi

## Setup some NGinX
read -d '' nginxconf << "CONF"
upstream jenkins {
  server 127.0.0.1:8080 fail_timeout=0;
}
 
server {
  listen 80;
  server_name jenkins.domain.tld;
  return 301 https://$host$request_uri;
}
 
server {
  listen 443 ssl;
  server_name jenkins.domain.tld;
 
  ssl_certificate /etc/nginx/ssl/server.crt;
  ssl_certificate_key /etc/nginx/ssl/server.crt;
 
  location / {
    proxy_set_header        Host $http_host;
    proxy_set_header        X-Real-IP $remote_addr;
    proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header        X-Forwarded-Proto $scheme;
    proxy_redirect http:// https://;
    proxy_pass              http://jenkins;
  }
}
CONF

mkdir -p /etc/nginx/ssl
/etc/pki/tls/certs/make-dummy-cert /etc/nginx/ssl/server.crt
echo "$nginxconf" > /etc/nginx/conf.d/jenkins.conf
mv /etc/nginx/conf.d/default.conf{,.bak}

## Restart Services
service nginx restart
service jenkins restart

## Wait for Jenkins and provide password
echo -n "Waiting for Jenkins to start.."
jenkins_check=1
timeout_check=0
while [ "${jenkins_check}" != 0 ]; do
cat /var/lib/jenkins/secrets/initialAdminPassword >/dev/null 2>&1
jenkins_check=$?
let "timeout_check+=1"
  if [ "${timeout_check}" -lt 60 ]; then
      sleep 1
  else
    echo "[FAIL] Jenkins took too long :( "
    exit 1
  fi
done

## Let the user know!!
JenkinsInitPasswd=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "All done!  You can access you install using the below info"
echo "Jenkins URL: https://$HOSTIP"
echo "Jenkins Password: $JenkinsInitPasswd"
