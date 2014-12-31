#!/bin/bash
######################################################
# h20 HTTP server installer for CentOS OS
# planned integration into centminmod.com
# written by George Liu (eva2000) vbtechsupport.com
# 
# restart
# killall h2o; /usr/local/bin/h2o -c /usr/local/h2o/h2o.conf &
######################################################
VER=0.1
# variables
#############
DT=`date +"%d%m%y-%H%M%S"`

HO_VER=0.9.0
CUSTOMCONF=y
USER=nginx

######################################################
DIR_TMP='/svr-setup'
SCRIPT_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))

if [ ! -d "$DIR_TMP" ]; then
	mkdir -p $DIR_TMP
fi

if [ -f /proc/user_beancounters ]; then
    # CPUS='1'
    # MAKETHREADS=" -j$CPUS"
    # speed up make
    CPUS=`cat "/proc/cpuinfo" | grep "processor"|wc -l`
    MAKETHREADS=" -j$CPUS"
else
    # speed up make
    CPUS=`cat "/proc/cpuinfo" | grep "processor"|wc -l`
    MAKETHREADS=" -j$CPUS"
fi
######################################################
# functions
#############

complete() {
	echo
	echo "H20 installed/updated"
	echo
	/usr/local/bin/h2o -v
	echo
	/usr/local/bin/h2o --help
}

download() {
	cd $DIR_TMP
	rm -rf v${HO_VER}.tar.gz
	wget -cnv --no-check-certificate https://github.com/h2o/h2o/archive/v${HO_VER}.tar.gz
	tar xzf v${HO_VER}.tar.gz
}

install() {
	if [[ -z "$(rpm -ql libyaml)" ]]; then
		yum -y install libyaml libyaml-devel
	fi
	if [[ -z "$(rpm -ql perl-devel)" ]]; then
		yum -y install perl-devel
	fi
	if [[ -z "$(rpm -ql perl-CPAN)" ]]; then
		yum -y install perl-CPAN
	fi
	echo "install cpanm"
	echo
	curl -L http://cpanmin.us | perl - App::cpanminus
	cpanm Server::Starter --force

	echo "install h2o server"
	echo
	cd $DIR_TMP
	cd h2o-${HO_VER}
	cmake -DCMAKE_INSTALL_PREFIX=/usr/local .
	make${MAKETHREADS}
	make install

	echo "setup /usr/local/h2o/h2o.conf"

	if [[ "$CUSTOMCONF" = [yY] ]]; then
		cd examples
		\cp -a h2o /usr/local

cat > "/usr/local/h2o/h2o.conf" <<EOF
# bind all listening ports to "0.0.0.0", so it can start with: start_server --port 0.0.0.0:8080 --port 0.0.0.0:8081 -- /usr/local/bin/h2o -c /usr/local/h2o/h2o.conf &

listen:
  host: 0.0.0.0
  port: 8080
max-connections: 10240
http1-request-timeout: 10
limit-request-body: 536870912
http1-upgrade-to-http2: ON
http2-idle-timeout: 10
http2-max-concurrent-requests-per-connection: 16
num-threads: $CPUS
user: $USER
listen:
  host: 0.0.0.0
  port: 8081
  ssl:
    certificate-file: /usr/local/h2o/server.crt
    key-file: /usr/local/h2o/server.key
hosts:
  "0.0.0.0:8080":
    paths:
      /:
        file.dir: /usr/local/nginx/html
    access-log: /usr/local/h2o/logs/access.log
  "alternate.127.0.0.1.xip.io:8081":
    listen:
      host: 0.0.0.0
      port: 8081
      ssl:
        certificate-file: /usr/local/h2o/alternate.crt
        key-file: /usr/local/h2o/alternate.key
    paths:
      /:
        file.dir: /usr/local/nginx/html.alternate
    access-log: /usr/local/h2o/logs/access-alternate.log
EOF

	else
		cd examples
		\cp -a h2o /usr/local
		sed -i 's/examples\/h2o/\/usr\/local\/h2o/g' /usr/local/h2o/h2o.conf
		sed -i 's/examples\/doc_root/\/usr\/local\/nginx\/html/g' /usr/local/h2o/h2o.conf
		sed -i 's/listen: 8080/listen: 8080\nuser: nginx/' /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nhttp2-max-concurrent-requests-per-connection: 16/" /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nhttp2-idle-timeout: 10/" /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nhttp1-upgrade-to-http2: ON/" /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nlimit-request-body: 536870912/" /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nhttp1-request-timeout: 10/" /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nnum-threads: $CPUS/" /usr/local/h2o/h2o.conf
		sed -i "s/listen: 8080/listen: 8080\nmax-connections: 10240/" /usr/local/h2o/h2o.conf
	fi

	echo "setup h2o log directory"
	mkdir -p /usr/local/h2o/logs
	touch /usr/local/h2o/logs/access.log
	touch /usr/local/h2o/logs/access-alternate.log
	chmod 0666 /usr/local/h2o/logs/access.log
	chmod 0666 /usr/local/h2o/logs/access-alternate.log
	chown nginx:nginx /usr/local/h2o/logs/access.log
	chown nginx:nginx /usr/local/h2o/logs/access-alternate.log
	sed -i 's/\/dev\/stdout/\/usr\/local\/h2o\/logs\/access.log/' /usr/local/h2o/h2o.conf
	sed -i 's/\/dev\/stdout/\/usr\/local\/h2o\/logs\/access-alternate.log/' /usr/local/h2o/h2o.conf

	ls -lah /usr/local/h2o/
	echo

	echo "/usr/local/bin/h2o -c /usr/local/h2o/h2o.conf &"
	echo "or"
	echo "start_server --port 0.0.0.0:8080 --port 0.0.0.0:8081 -- /usr/local/bin/h2o -c /usr/local/h2o/h2o.conf &"
	echo
	complete
}

hupdate() {
	cd $DIR_TMP
	cd h2o-${HO_VER}
	rm -rf CMakeCache.txt
	cmake -DCMAKE_INSTALL_PREFIX=/usr/local .
	make${MAKETHREADS}
	make install
	complete
}
######################################################
case "$1" in
	install )
		download
		install
		;;
	update )
		download
		hupdate
		;;
	pattern )
		;;
	pattern )
		;;
	pattern )
		;;
	pattern )
		;;
	* )
		echo "$0 {install|update}"
		;;
esac

exit