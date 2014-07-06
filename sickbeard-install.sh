#! /usr/bin/env bash

if [ "$(whoami)" != "root" ]; then
	echo "This script needs to be run as root."
	exit 1
fi

# Install dependnecies
yum -y install python python-cheetah

# Begin sickbeard setup
SB_GIT="git://github.com/midgetspy/Sick-Beard.git"

DEFAULT_USER=sickbeard
SB_USER=$([ -z "$1" ] && echo $DEFAULT_USER || echo $1)
SB_HOME=/opt/sickbeard

SB_INIT_SRC=${SB_HOME}/init.fedora
SB_INIT_DST=/etc/init.d/sickbeard

SB_SERVICE_CFG=/etc/sysconfig/sickbeard
SB_SERVICE_PORT=8081
SB_SERVICE_HOST=localhost
SB_SERVICE_PROT=http

## Set up user and group as required
if [ "$DEFAULT_USER" == "$SB_USER" ]; then
	useradd --system --user-group --home "$SB_HOME" $SB_USER
else
	if [ -z "(grep \"^$SB_USER:\" /etc/passwd)" ]; then
		echo "Invalid user specified"
		exit 1
	fi
	groupadd --system $DEFAULT_USER
	usermod --append --groups $DEFAULT_USER $SB_USER
fi

# Fetch the code
git clone $SB_GIT "$SB_HOME"
chmod 700 "$SB_HOME"
chown -R $SB_USER:$SB_USER "$SB_HOME"

cat > /usr/bin/sickbeard << EOF
#!/bin/bash
python $SB_HOME/SickBeard.py \$@
EOF

chmod 755 /usr/bin/sickbeard
chown $SB_USER:$SB_USER /usr/bin/sickbeard

## Service configuration
cat > $SB_SERVICE_CFG << EOF
# Sickbeard service configuration

#run Sickbeard as
SB_USER=$SB_USER
SB_HOME=$SB_HOME
SB_PIDFILE=/var/run/sickbeard/sickbeard.pid

#gui address, eg: \${protocol}://\${host}:\${port}/sickbeard/
protocol=$SB_SERVICE_PROT
host=$SB_SERVICE_HOST
port=$SB_SERVICE_PORT

#leave blank if no username/password is required to access the gui
username=
password=

#use nice, ionice, taskset to start SABnzbd
nicecmd=
#  example: nicecmd="nice -n 19 ionice -c3"
EOF

chmod 644 $SB_SERVICE_CFG

## init.d script
cp $SB_INIT_SRC $SB_INIT_DST
chmod 755 /etc/init.d/sickbeard

# start on boot
chkconfig --levels 345 sickbeard on
