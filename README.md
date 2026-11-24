# NGINX Mainline Alpine

基于 `nginx:mainline-alpine`，从 NGINX Mainline 源码构建并静态编入 Brotli、GeoIP2 和 Zstandard 模块。保留官方镜像的入口脚本、默认配置和端口。发布到 GHCR 的每个标签都包含 `linux/amd64` 和 `linux/arm64`，Docker 会自动选择所需架构。

## 拉取和运行

将 `owner/repository` 替换为 GitHub 仓库名称的小写形式。

```sh
docker pull ghcr.io/lostars/nginx:mainline-alpine
docker run --rm -p 8080:80 ghcr.io/owner/repository:mainline-alpine
```

每次发布更新 `mainline-alpine`、`alpine` 和带 `-alpine` 后缀的版本标签，例如 `1.31.10-alpine`、`1.31-alpine` 和 `1-alpine`。同一次发布的所有标签都指向同一份双架构镜像。 [NGINX 官方标签列表](https://github.com/docker-library/official-images/blob/master/library/nginx)

## 模块配置

将以下压缩配置放在 `/etc/nginx/conf.d/` 下的 `.conf` 文件里，或按需写入自定义的 `server` 或 `location` 配置。 [Brotli 模块文档](https://github.com/google/ngx_brotli#configuration-directives) [Zstandard 模块文档](https://github.com/tokers/zstd-nginx-module#directives)

```nginx
brotli on;
brotli_static on;
zstd on;
zstd_static on;
```

GeoIP2 需要自行提供 MaxMind `.mmdb` 数据库。将数据库以只读方式挂载到容器，再在 `http` 块中配置数据库和变量。 [GeoIP2 模块文档](https://github.com/leev/ngx_http_geoip2_module#example-usage)

```nginx
geoip2 /etc/nginx/geoip/GeoLite2-Country.mmdb {
    $geoip2_country_code country iso_code;
}
```

基础镜像自带的可选动态模块需要与编译出的 NGINX 版本匹配。官网先发布新版源码时，使用这些动态模块的配置需配套使用同版本的 `.so` 文件。

## 构建和发布

发布工作流在默认分支每天 03:23 UTC 执行，也可在 GitHub 的 **Actions → Publish NGINX Mainline → Run workflow** 中手动运行。每次运行从 NGINX 官网获取最新 Mainline 版本，在 amd64 和 arm64 原生 runner 上并行编译。两个架构构建成功后，工作流合并并用仓库的 `GITHUB_TOKEN` 发布到 `ghcr.io/<owner>/<repository>`。首次发布后可在 GitHub Packages 中管理可见性和访问权限。 [工作流配置](.github/workflows/publish-nginx.yml) [NGINX 下载页](https://nginx.org/en/download.html) [GHCR 文档](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

本地构建时，将 `NGINX_SOURCE_VERSION` 设置为要编译的 Mainline 版本。每次构建都会读取三个模块仓库默认分支的最新提交。Brotli 库随 `ngx_brotli` 的子模块一起获取。 [Dockerfile](Dockerfile)

```sh
docker buildx build --pull --load \
  --build-arg NGINX_SOURCE_VERSION=1.31.10 \
  -t nginx-custom:local .
docker run --rm nginx-custom:local nginx -t
```
