CRAN Check Results API
======================

The was originally just rOpenSci packages, but is now all packages on CRAN.

Base URL: <https://cranchecks.info>

[API Docs](docs/api_docs.md)

tech:

* language: Ruby
* rest framework: Sinatra
* http requests: faraday
* database: mongodb
* server: caddy
* container: all wrapped up in docker (docker-compose)
* uses Gábor's <https://crandb.r-pkg.org> API to get names of CRAN packages

