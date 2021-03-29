#!/bin/bash
OS='${operating_system}'
RELEASE_VERSION='${release_version}'

if [ "$${OS:0:6}" = "centos" ] || [ "$${OS:0:4}" = "rhel" ]; then
REPO_PATH="/etc/yum.repos.d/CentOS-Upgrade.repo"
cat <<"EOF" >$REPO_PATH
[base-vault]
name=CentOS-$releasever - Base
baseurl=http://vault.centos.org/$releasever/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-8
[updates-vault]
name=CentOS-$releasever - Updates
baseurl=http://vault.centos.org/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-8
[extras-vault]
name=CentOS-$releasever - Extras
baseurl=http://vault.centos.org/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-8
EOF
yum upgrade -y --disablerepo=* --enablerepo=base-vault --enablerepo=updates-vault --enablerepo=extras-vault --releasever=$RELEASE_VERSION
rm -f $REPO_PATH
fi
