if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <branch name>"
  exit 1
fi
readonly branch=$1

source "$(dirname "$0")/config.sh"

set -eux

# prepare
pushd ${REPO_ROOT_DIR}
readonly old_working_branch=$(git branch --show-current)
git fetch origin
git checkout ${branch}
git pull origin ${branch}

###
# refresh logs
###

# refresh nginx access & error log
sudo truncate --size 0 $NGINX_ACCESS_LOG $NGINX_ERROR_LOG

# refresh mysql slow query log
sudo truncate --size 0 $MYSQL_SLOW_LOG
# sudo mysqladmin flush-logs

###
# deploy
###

# deploy env.sh
cp ${REPO_ROOT_DIR}/conf/env.sh /home/isucon/

# deploy mysql
sudo cp $MYSQL_CONF_SRC $MYSQL_CONF_DEST
sudo systemctl restart mysql

# deploy memcached
sudo cp $MEMCACHED_CONF_SRC $MEMCACHED_CONF_DEST
sudo systemctl restart memcached

# deploy nginx
sudo cp $NGINX_ROOT_CONF_SRC $NGINX_ROOT_CONF_DEST
sudo cp $NGINX_SITE_CONF_SRC $NGINX_SITE_CONF_DEST
sudo systemctl reload nginx

# deploy go
(
  cd $GO_APP_DIR
  $GO build -o $GO_APP_FILENAME
)
sudo systemctl restart ${GO_SERVICE_NAME}
timeout 5 bash -c "while ! systemctl is-active ${GO_SERVICE_NAME}; do sleep 0.1; done "  # wait for restart webapp

###
# prepare benchmark
###

# start profile
mkdir -p ${PPORF_DIR}
curl "http://localhost:${GO_PORT}/api/pprof/start?path=${PPORF_DIR}/"

# cleanup
git checkout "${old_working_branch}"
popd
