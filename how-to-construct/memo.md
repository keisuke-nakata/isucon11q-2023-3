# 環境立ち上げ

https://github.com/isucon/isucon11-qualify/tree/main/provisioning/cf-kakomon の cf.yaml をダウンロードし、アプリ3つ・ベンチの AMI を
https://github.com/matsuu/aws-isucon#ami に書かれているものに変更。
書き換え済みのものが [cf.yaml](cf.yaml)

cloud formation から↑のコンフィグを import してウィザードを進める。
key-pair だけ、事前に作っておいたやつを指定する。その他は何も設定せずに進む。

# 環境セットアップ

https://github.com/y011d4/inisucon からリリースファイルをローカルに落としてくる。
適当に設定ファイルを作成し、

```bash
./inisucon add -f CONFIG_PATH
./inisucon show
```

これで表示された ".ssh/config" をローカルの .ssh/config に追記する。

次を実行：

```bash
./inisucon setup --all
```

セットアップ後、各インスタンスに SSH 接続できるか確認。

# git init

github で repository を作成し、 `./inisucon show` で表示された "pubkey of deploy key" を deploy key に登録する (write アクセス付き)。

適当なインスタンスで以下を実行：

```bash
git init
git add .
git commit -m "initial"
git branch -M main
git remote add origin git@github.com:keisuke-nakata/isucon11q-2023-3.git
git push -u origin main
```

他のインスタンスでは以下を実行：

```bash
original_dir=webapp
mv ${original_dir} ${original_dir}.bk
git clone git@github.com:keisuke-nakata/isucon11q-2023-3.git ${original_dir}
```

# はじめての bench

https://github.com/matsuu/cloud-init-isucon/blob/main/isucon11q/README.md#bench を参考に、bench インスタンスで以下を実行：

```bash
./bench -all-addresses 192.168.0.11,192.168.0.12,192.168.0.13 -target 192.168.0.11:443 -tls -jia-service-url http://192.168.0.10:4999
```

# snapshot 準備

適当な場所から snapshot をパクってきて、config を書き換える。
そして init.sh を実行

# profiler を仕込む

対応する場所に以下を仕込む。

### "github.com/go-chi/chi/v5" の場合:

```go
import (
	...
	"github.com/pkg/profile"
)

...

var profiler interface{ Stop() }

...

	// pprof
	r.Get("/api/pprof/start", getProfileStart)
	r.Get("/api/pprof/stop", getProfileStop)

...

func getProfileStart(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	profiler = profile.Start(profile.ProfilePath(path))
	w.WriteHeader(http.StatusOK)
}

func getProfileStop(w http.ResponseWriter, r *http.Request) {
	profiler.Stop()
	w.WriteHeader(http.StatusOK)
}
```

### "github.com/labstack/echo/v4" の場合

```go
import (
	...
	"github.com/pkg/profile"
)
...

var profiler interface{ Stop() }

...

	// pprof
	e.GET("/api/pprof/start", getProfileStart)
	e.GET("/api/pprof/stop", getProfileStop)

...

func getProfileStart(c echo.Context) error {
	path := c.QueryParam("path")
	profiler = profile.Start(profile.ProfilePath(path))
	return c.JSON(http.StatusOK, "pprof start ok")
}

func getProfileStop(c echo.Context) error {
	profiler.Stop()
	return c.JSON(http.StatusOK, "pprof stop ok")
}
```

### チェック

```console
$ cd $REPO_ROOT_DIR/go
$ git pull origin main
$ $GO build -o isucondition
$ sudo systemctl restart isucondition.go
$ curl "http://localhost:${GO_PORT}/api/pprof/start?path=/home/isucon/pprof/"
# ここで適当にアプリにアクセスして、profile を取得
$ curl "http://localhost:${GO_PORT}/api/pprof/stop"
$ $GO tool pprof --pdf /home/isucon/pprof/cpu.pprof > /home/isucon/pprof/prof.pdf
```

# nginx の log を json にする

適当に過去の設定をパクってくる

# mysql の slow log query を on にする

適当に過去の設定をパクってくる

# mysql を appserver3 に任せる

`/etc/mysql/mariadb.conf.d/50-server.cnf` で bind-address = 0.0.0.0 とする (初期は127.0.0.1)

appserver3 で `mysql -u isucon -D isucondition -p` でログインし、以下を実行：
```sql
SELECT Host, User FROM mysql.user;
GRANT ALL ON isucondition.* to 'isucon'@'192.168.0.11' IDENTIFIED BY 'isucon';
GRANT ALL ON isucondition.* to 'isucon'@'192.168.0.12' IDENTIFIED BY 'isucon';
```

`sudo systemctl restart mysql` で再起動してから、
appserver1,2 で `mysql -u isucon -D isucondition -h 192.168.0.13 -p` でログインできればOK.

初期化用データが gitignore されているので、.gitignore を編集してから sql/1_InitData.sql を push しておく。

env.sh で MYSQL_HOST を 192.168.0.13 へ

# nginx で load balancer を仕込む


`isucondition.conf` に追記：

```nginx
upstream app {
    server 192.168.0.11:3000 weight=1;
    server 192.168.0.12:3000 weight=2;
}

server {
    ...
    location / {
		...
        proxy_pass http://app;
    }
}

```

# memcache を appserver2 に任せる

`/etc/memcached.conf` で -l 0.0.0.0 とする (初期は127.0.0.1)

appserver2 で `sudo systemctl restart memcached` してから、appserver1,3 で 
`telnet 192.168.0.12 11211` で接続して、以下のコマンドがいい感じに通ればOK:

```
set key1 0 0 6   # <flags> <ttl> <size>
value1

get key1

quit
```

go を書き換える：

```go
import (
	...
	"github.com/bradfitz/gomemcache/memcache"
)

...

var memcacheClient *memcache.Client

...

func checkMemcacheClient() error {
	err := memcacheClient.Set(&memcache.Item{Key: "key1", Value: []byte("value1"), Expiration: 10})
	if err != nil {
		log.Fatalf("failed to Set memcached: %v", err)
		return err
	}
	val, err := memcacheClient.Get("key1")
	if err != nil {
		log.Fatalf("failed to Get memcached: %v", err)
		return err
	} else {
		log.Debugf("memcached: %v", string(val.Value))
	}
	err = memcacheClient.Set(&memcache.Item{Key: "key2", Value: []byte("value2"), Expiration: 10})
	if err != nil {
		log.Fatalf("failed to Set memcached: %v", err)
		return err
	}
	keys := []string{"key1", "key2", "key3"}
	vals, err := memcacheClient.GetMulti(keys)
	if err != nil {
		log.Fatalf("failed to GetMulti memcached: %v", err)
		return err
	} else {
		for _, key := range keys {
			val, ok := vals[key]
			if ok {
				log.Debugf("memcached: %v", string(val.Value))
			} else {
				log.Debugf("failed to GetMulti memcached: %v", key)
			}
		}
	}

	return nil
}

...

func init() {
	...
	memAddr := "192.168.0.12:11211"
	memcacheClient = memcache.New(memAddr)
	err = checkMemcacheClient()
	if err != nil {
		panic(err)
	}
}

...
```
