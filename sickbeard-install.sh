# Install dependnecies
yum --quiet -y install python python-cheetah

# Begin sickbeard setup
DEFAULT_USER=sickbeard
SICKBEARD_USER=$([ -z "$1" ] && echo $DEFAULT_USER || echo $1)
SICKBEARD_HOME=/usr/share/sickbeard
SICKBEARD_GIT="git://github.com/midgetspy/Sick-Beard.git"

if [ "$DEFAULT_USER" == "$SICKBEARD_HOME" ]; then
	useradd --system --user-group --home "$SICKBEARD_HOME" $SICKBEARD_USER
else
	if [ -z "(grep \"^$SICKBEARD_USER:\" /etc/passwd)" ]; then
		echo "Invalid user specified"
		exit 1
	fi
	groupadd --system $DEFAULT_USER
	usermod --append --groups $DEFAULT_USER $SICKBEARD_USER	
fi

git clone $SICKBEARD_GIT "$SICKBEARD_HOME"
chmod 770 "$SICKBEARD_HOME"
chown -R $SICKBEARD_USER:$SICKBEARD_USER "$SICKBEARD_HOME"

cat > /usr/bin/sickbeard << EOF
#!/bin/bash
python $SICKBEARD_HOME/SickBeard.py \$@
EOF

chmod 755 /usr/bin/sickbeard
chown $SICKBEARD_USER:$SICKBEARD_USER /usr/bin/sickbeard

##
## Source: http://sickbeard.com/forums/viewtopic.php?f=6&t=2415
##

## Service configuration
cat > /etc/sysconfig/sickbeard << EOF
# Sickbeard service configuration

#run Sickbeard as
SICKBEARD_USER=$SICKBEARD_USER
SICKBEARD_HOME=$SICKBEARD_HOME
SICKBEARD_PIDFILE=/var/run/sickbeard/sickbeard.pid

#gui address, eg: \${protocol}://\${host}:\${port}/sickbeard/
protocol=http
host=localhost
port=8081

#leave blank if no username/password is required to access the gui
username=
password=

#use nice, ionice, taskset to start SABnzbd
nicecmd=
#  example: nicecmd="nice -n 19 ionice -c3"
EOF

chmod 744 /etc/sysconfig/sickbeard

## init.d script
cat > /etc/init.d/sickbeard << EOF
#!/bin/sh -

### BEGIN INIT INFO
# Provides:          Sick Beard application instance
# Required-Start:    \$all
# Required-Stop:     \$all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts Sick Beard
# Description:       starts Sick Beard
### END INIT INFO

# Source function library.
. /etc/init.d/functions

# Source SickBeard configuration
if [ -f /etc/sysconfig/sickbeard ]; then
    . /etc/sysconfig/sickbeard
fi

prog=sickbeard
lockfile=/var/lock/subsys/\$prog

## Edit user configuation in /etc/sysconfig/sickbeard to change
## the defaults
username=\${SICKBEARD_USER-sickbeard}
homedir=\${SICKBEARD_HOME-/opt/sickbeard}
pidfile=\${SICKBEARD_PIDFILE-/var/run/sickbeard/sickbeard.pid}
nice=\${SICKBEARD_NICE-}
##

pidpath=\`dirname \${pidfile}\`
options=" --daemon --pidfile=\${pidfile}"

# create PID directory if not exist and ensure the SickBeard user can write to it
if [ ! -d \$pidpath ]; then
    mkdir -p \$pidpath
    chown \$username \$pidpath
fi

start() {
    # Start daemon.
    echo -n \$"Starting \$prog: "
    daemon --user=\${username} --pidfile=\${pidfile} \${nice} python \${homedir}/SickBeard.py \${options}
    RETVAL=\$?
    echo
    [ \$RETVAL -eq 0 ] && touch \$lockfile
    return \$RETVAL
}

stop() {
    echo -n \$"Shutting down \$prog: "
    killproc -p \${pidfile} python
    RETVAL=\$?
    echo
#        [ \$RETVAL -eq 0 ] && rm -f \$lockfile
    return \$RETVAL
}

# See how we were called.
case "\$1" in
start)
    start
    ;;
stop)
    stop
    ;;
status)
    status \$prog
    ;;
restart|force-reload)
    stop
    start
    ;;
try-restart|condrestart)
    if status \$prog > /dev/null; then
        stop
        start
    fi
    ;;
reload)
    exit 3
    ;;
*)
    echo \$"Usage: \$0 {start|stop|status|restart|try-restart|force-reload}"
    exit 2
esac
EOF

chmod 755 /etc/init.d/sickbeard

# start on boot
chkconfig --levels 345 sickbeard on
