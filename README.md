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

> you'll need curl (which you likely have), and jq (<https://stedolan.github.io/jq/>) which you may not have

All pkgs from a maintainer that have any checks not passing

```sh
curl https://cranchecks.info/maintainers/csardi.gabor_at_gmail.com | jq '.data.table[] | select(.any) | .package'
```

Similar but across all packages

```sh
curl https://cranchecks.info/pkgs?limit=10 | jq '.data[] | select(.summary.any) | .package'
```

Packages that have error status checks

```sh
curl https://cranchecks.info/pkgs?limit=1000 | jq '.data[] | select(.summary.error > 0) | .package'
```

## Badges

package status summaries

- `/badges/clean/:package` all okay? 
- `/badges/worst/:package` worst result, error <- warn <- note 
- `/badges/noerrors/:package` no errors? but could have warnings or notes 
- `/badges/nowarns/:package` no warns? no errors, no warnings, but could have notes 
- `/badges/nonotes/:package` no notes? no errors, no warnings, and no notes

per flavor

- `/badges/flavor/:flavor/:package` flavor + package, e.g., `r-devel-linux-x86_64-fedora-gcc`

examples:

both badges routes

![](svgs/unknown.svg)

package summary route

![](svgs/ok.svg)
![](svgs/notok.svg)

flavor route

![](svgs/note.svg)
![](svgs/warn.svg)
![](svgs/error.svg)

[cchecks]: https://github.com/ropenscilabs/cchecks


