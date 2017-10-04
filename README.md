CRAN Check Results API
======================

The was originally just rOpenSci packages, but is now all packages on CRAN.

Base URL: <https://cranchecks.info>

tech:

* language: Ruby
* rest framework: Sinatra
* http requests: faraday
* database: mongodb
* server: caddy
* container: all wrapped up in docker (docker-compose)

Uses Gábor's <https://crandb.r-pkg.org> API to get names of CRAN packages.

## routes

* `/`
* `/heartbeat`
* `/docs`
* `/pkgs`
* `/pkgs/:pkg_name:`

### /heartbeat

```sh
curl https://cranchecks.info/heartbeat | jq .
```

```json
{
  "routes": [
    "/docs (GET)",
    "/heartbeat (GET)",
    "/pkgs (GET)",
    "/pkgs/:pkg_name: (GET)"
  ]
}
```

### /pkgs

```sh
curl https://cranchecks.info/pkgs | jq .
```

```json
{
  "found": 252,
  "count": 10,
  "offset": 0,
  "error": null,
  "data": [
    {
      "_id": "AntWeb",
      "_rev": "1-9a936a55e375a94c648b6c5b846205c9",
      "package": "AntWeb",
      "checks": [
        {
          "Flavor": "r-devel-linux-x86_64-debian-clang ",
          "Version": "0.7 ",
          "Tinstall": "1.03 ",
          "Tcheck": "15.32 ",
          "Ttotal": "16.35 ",
          "Status": "NOTE"
...
```

### /pkgs/:pkg_name

```sh
curl https://cranchecks.info/pkgs/solrium | jq .
```

```json
{
  "error": null,
  "data": {
    "_id": "solrium",
    "package": "solrium",
    "checks": [
      {
        "Flavor": "r-devel-linux-x86_64-debian-clang ",
        "Version": "0.4.0 ",
        "Tinstall": "1.89 ",
        "Tcheck": "34.40 ",
        "Ttotal": "36.29 ",
        "Status": "OK",
        "check_url": "https://www.R-project.org/nosvn/R.check/r-devel-linux-x86_64-debian-clang/solrium-00check.html"
      },
...
```
