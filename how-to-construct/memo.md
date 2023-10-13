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



memcche の話
