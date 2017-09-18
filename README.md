CRAN Check Results API
======================

Right now, this only concerns itself with rOpenSci packages on CRAN - but can easily add all pkgs on CRAN if there's a need.

Base URL: https://cranchecks.info

tech:

* language: Ruby
* rest framework: Sinatra
* http requests: faraday
* database: mongodb
* server: caddy
* container: all wrapped up in docker

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
    "_rev": "1-d95aa09066451b92c59b3f108fd1b149",
    "package": "solrium",
    "checks": [
      {
        "Flavor": "r-devel-linux-x86_64-debian-clang ",
        "Version": "0.4.0 ",
        "Tinstall": "1.82 ",
        "Tcheck": "1800.07 ",
        "Ttotal": "1801.89 ",
        "Status": "FAIL",
        "check_url": "https://www.R-project.org/nosvn/R.check/r-devel-linux-x86_64-debian-gcc/solrium-00check.html"
      },
...
```
