readonly SSH="ssh -o StrictHostKeyChecking=no"

readonly APPSERVER1_PRIVATE_IP=192.168.0.11
readonly APPSERVER2_PRIVATE_IP=192.168.0.12
readonly APPSERVER3_PRIVATE_IP=192.168.0.13

readonly REPO_ROOT_DIR=/home/isucon/webapp
readonly SNAPSHOT_SCRIPT_DIR=$REPO_ROOT_DIR/snapshot
readonly RESULT_BASE_DIR=$REPO_ROOT_DIR/result
readonly CONF_DIR=$REPO_ROOT_DIR/conf
readonly PPORF_DIR=/home/isucon/pprof

# mysql
readonly MYSQL_CONF_SRC=$CONF_DIR/sql/50-server.cnf
readonly MYSQL_SLOW_LOG=/var/log/mysql/mysql-slow.log
readonly MYSQL_CONF_DEST=/etc/mysql/mariadb.conf.d/50-server.cnf

# nginx
readonly NGINX_ROOT_CONF_SRC=$CONF_DIR/nginx/nginx.conf
readonly NGINX_ROOT_CONF_DEST=/etc/nginx/nginx.conf
readonly NGINX_SITE_CONF_SRC=$CONF_DIR/nginx/isucondition.conf
readonly NGINX_SITE_CONF_DEST=/etc/nginx/sites-available/isucondition.conf
readonly NGINX_ACCESS_LOG=/var/log/nginx/access.log
readonly NGINX_ERROR_LOG=/var/log/nginx/error.log

# memcache
readonly MEMCACHED_CONF_SRC=$CONF_DIR/memcached/memcached.conf
readonly MEMCACHED_CONF_DEST=/etc/memcached.conf
readonly MEMCACHED_PORT=11211

# go
readonly GO="/home/isucon/local/go/bin/go"
readonly GO_PORT=3000
readonly GO_APP_DIR=$REPO_ROOT_DIR/go
readonly GO_APP_FILENAME=isucondition  # makefile が提供されてるならそっちを使ったほうが良いと思う
readonly GO_SERVICE_NAME=isucondition.go

# alp
readonly UUID_REGEX="[0-9a-f\-]{36}"
readonly ALP_PATTERN="/api/condition/${UUID_REGEX}$,/api/isu/${UUID_REGEX}$,/api/isu/${UUID_REGEX}/graph$,/api/isu/${UUID_REGEX}/icon$"
