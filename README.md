CRAN Check Results API
======================

The was originally just rOpenSci packages, but is now all packages on CRAN.

Base URL: <https://cranchecks.info/>

[API Docs](docs/api_docs.md)

No authentication needed

Check out [cchecks][] for an R package interface to this API

tech:

* language: Ruby
* rest framework: Sinatra
* http requests: faraday
* database: mongodb
* server: caddy
* container: all wrapped up in docker (docker-compose)
* uses Gábor's <https://crandb.r-pkg.org> API to get names of CRAN packages
* A cron job scrapes pkg specific data and maintainer level data once a day

## examples

All pkgs from a maintainer that have any checks not passing

```
curl https://cranchecks.info/maintainers/csardi.gabor_at_gmail.com | jq '.data.table[] | select(.any) | .package'
```

Similar but across all packages

```
curl https://cranchecks.info/pkgs?limit=10 | jq '.data[] | select(.summary.any) | .package'
```

Packages that have error status checks

```
curl https://cranchecks.info/pkgs?limit=1000 | jq '.data[] | select(.summary.error > 0) | .package'
```

[cchecks]: https://github.com/ropenscilabs/cchecks
