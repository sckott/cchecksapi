# CRAN checks API

## Contents

* [Base url](#base-url)
* [HTTP methods](#http-methods)
* [Response codes](#response-codes)
* [Media types](#media-types)
* [Pagination](#pagination)
* [Authentication](#authentication)
* [Parameters](#parameters)
    * [Common parameters](#common-parameters)
* [Routes](#routes)
    * [root](#root)
    * [heartbeat](#heartbeat)
    * [docs](#docs)
    * [packages](#packages)
    * [package by name](#package-by-name)
    * [package by name (history)](#package-by-name-history)
    * [maintainers](#maintainers)
    * [maintainer by email](#maintainer-summary-by-email)
    * [badges summary](#badges-summary)
    * [badges worst](#badges-worst)
    * [badges flavor](#badges-flavor)
* [Examples](#examples)

## Base URL

<https://cranchecks.info/>

## HTTP methods

This is a `read only` API. That is, we only allow `GET` (and `HEAD`) requests on this API.

Requests of all other types will be rejected with appropriate `405` code.

## Response Codes

* 200 (OK) - request good!
* 302 (Found) - the root `/`, redirects to `/heartbeat`, and `/docs` redirects to these documents
* 400 (Bad request) - When you have a malformed request, fix it and try again
* 404 (Not found) - When you request a route that does not exist, fix it and try again
* 405 (Method not allowed) - When you use a prohibited HTTP method (we only allow `GET` and `HEAD`)
* 500 (Internal server error) - Server got itself in trouble; get in touch with us. (in [Issues](https://github.com/ropensci/roapi/issues))


`400` responses will look something like

```
HTTP/1.1 400 Bad Request
Cache-Control: public, must-revalidate, max-age=60
Connection: close
Content-Length: 61
Content-Type: application/json
Date: Thu, 26 Feb 2015 23:27:57 GMT
Server: nginx/1.7.9
Status: 400 Bad Request
X-Content-Type-Options: nosniff

{
    "error": "invalid request",
    "message": "maximum limit is 5000"
}
```

`404` responses will look something like

```
HTTP/1.1 404 Not Found
Cache-Control: public, must-revalidate, max-age=60
Connection: close
Content-Length: 27
Content-Type: application/json
Date: Thu, 26 Feb 2015 23:27:16 GMT
Server: nginx/1.7.9
Status: 404 Not Found
X-Cascade: pass
X-Content-Type-Options: nosniff

{
    "error": "route not found"
}
```

`405` responses will look something like (with an empty body)

```
HTTP/1.1 405 Method Not Allowed
Access-Control-Allow-Methods: HEAD, GET
Access-Control-Allow-Origin: *
Cache-Control: public, must-revalidate, max-age=60
Connection: close
Content-Length: 0
Content-Type: application/json; charset=utf8
Date: Mon, 27 Jul 2015 20:48:27 GMT
Server: nginx/1.9.3
Status: 405 Method Not Allowed
X-Content-Type-Options: nosniff
```

`500` responses will look something like

```
HTTP/1.1 500 Internal Server Error
Cache-Control: public, must-revalidate, max-age=60
Connection: close
Content-Length: 24
Content-Type: application/json
Date: Thu, 26 Feb 2015 23:19:57 GMT
Server: nginx/1.7.9
Status: 500 Internal Server Error
X-Content-Type-Options: nosniff

{
    "error": "server error"
}
```

### Response headers

`200` response header will look something like

```
HTTP/2 200
access-control-allow-methods: HEAD, GET
access-control-allow-origin: *
cache-control: public, must-revalidate, max-age=60
content-type: application/json; charset=utf8
server: Caddy
x-content-type-options: nosniff
content-length: 2823
date: Thu, 17 May 2018 21:40:32 GMT
```

### Badge Response headers

`200` response header will look something like

```
HTTP/2 200
cache-control: max-age=300, public
content-type: image/svg+xml; charset=utf-8
expires: Thu, 17 May 2018 21:39:42 GMT
server: Caddy
x-content-type-options: nosniff
content-length: 855
date: Thu, 17 May 2018 21:39:41 GMT
```

### Response bodies

Response bodies generally look like:

```json
[{
    "count": 1,
    "data": [
    {
        "AnaCat": "potamodromous",
        "AquacultureRef": 12108,
        "Aquarium": "never/rarely",
        "AquariumFishII": " ",
        "AquariumRef": null,
        "Author": "(Linnaeus, 1758)",
        ...<cutoff>
    }
    ],
    "error": null,
    "returned": 1
}]
```

Successful requests have 4 slots:

* found: Number records found
* count: Number records returned
* offset: offset value
* error: If an error did not occur this is `null`, otherwise, an error message.
* data: The hash of data if any data returned. If no data found, this is an empty hash (hash of length zero)


### Response svg

svg response bodies generally look like:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="70" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <mask id="a">
    <rect width="70" height="20" rx="3" fill="#fff"/>
  </mask>
  <g mask="url(#a)">
    <path fill="#555" d="M0 0h43v20H0z"/>
    <path fill="#4c1" d="M43 0h46.5v20H43z"/>
    <path fill="url(#b)" d="M0 0h70v20H0z"/>
  </g>
  <g fill="#fff" text-anchor="middle"
     font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="21.5" y="15" fill="#010101" fill-opacity=".3">
      CRAN
    </text>
    <text x="21.5" y="14">
      CRAN
    </text>
    <text x="55.5" y="15" fill="#010101" fill-opacity=".3">
      OK
    </text>
    <text x="55.5" y="14">
      OK
    </text>
  </g>
</svg>
```


## Media Types

We serve up only JSON in this API. All responses will have `Content-Type: application/json; charset=utf8`.

## Pagination

The query parameters `limit` (default = 10) and `offset` (default = 0) can be sent.

The response body from the server will include data on records found in `found` and number returned in `count`:

* `"found": 1056`
* `"count": 10`


## Authentication

We don't use any. Cheers :)

## Parameters

### Common parameters

+ limit (integer, optional) `number` of records to return.
    + Default: `10`
+ offset (integer, optional) Record `number` to start at.
    + Default: `0`

Above parameters can be used only on `/pkgs` and `/maintainers`

## Routes

### root

> GET [/]

Get heartbeat for the cranchecks API [GET]

This path redirects to `/heartbeat`

+ Response 302 (application/json)



### heartbeat

> GET [/heartbeat]

Get heartbeat for the Fishbase API [GET]

+ Response 200
    + [Headers](#response-headers)
    + Body
    ```
    {
      "routes": [
        "/docs (GET)",
        "/heartbeat (GET)",
        "/pkgs (GET)",
        "/pkgs/:pkg_name: (GET)"
      ]
    }
    ```

### docs

> GET [/docs]

Redirects to docs at github repo

+ Response 301
    + [Headers](#response-headers)

### packages

> GET [/pkgs]

Get all repositories.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### package by name

> GET [/pkgs/{package_name}]

Get package by name.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### package by name (history)

> GET [/pkgs/{package_name}/history]

Get last 30 days of checks for a package name.

For the history routes, we keep the last 30 days of checks for each package; each day we purge any checks data older than 30 days

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### maintainers

> GET [/maintainers]

Get all maintainers.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### maintainer summary by email

> GET [/maintainers/{maintainer_email}]

Get maintainer summary by email.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### badges summary

> GET [/badges/summary/{package_name}]

Get badge for CRAN checks summary by package name.

+ Response 200 (image/svg+xml)
    + [Headers](#badge-response-headers)
    + [Body](#response-svg)

### badges worst

> GET [/badges/worst/{package_name}]

Get badge for CRAN checks worst result by package name.

+ Response 200 (image/svg+xml)
    + [Headers](#badge-response-headers)
    + [Body](#response-svg)

### badges flavor

> GET [/badges/flavor/{flavor}/{package_name}]

Get badge for summary of CRAN checks by flavor and package name.

+ Response 200 (image/svg+xml)
    + [Headers](#badge-response-headers)
    + [Body](#response-svg)


## Examples

### /heartbeat

```sh
curl https://cranchecks.info/heartbeat/ | jq .
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
curl https://cranchecks.info/pkgs/ | jq .
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
curl https://cranchecks.info/pkgs/solrium/ | jq .
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

### /maintainers

```sh
curl https://cranchecks.info/maintainers/ | jq .
```

```json
{
  "found": 6732,
  "count": 10,
  "offset": null,
  "error": null,
  "data": [
    {
      "_id": "00gerhard_at_gmail.com",
      "email": "00gerhard_at_gmail.com",
      "name": "Daniel Gerhard",
      "url": "https://cran.rstudio.com/web/checks/check_results_00gerhard_at_gmail.com.html",
      "table": [
        {
          "package": "goric",
          "ok": 12
        },
...
```

### /maintainers/:email

```sh
curl https://cranchecks.info/maintainers/csardi.gabor_at_gmail.com | jq .
```

```json
{
  "error": null,
  "data": {
    "_id": "csardi.gabor_at_gmail.com",
    "email": "csardi.gabor_at_gmail.com",
    "name": "Gábor Csárdi",
    "url": "https://cran.rstudio.com/web/checks/check_results_csardi.gabor_at_gmail.com.html",
    "table": [
      {
        "package": "clisymbols",
        "error": 0,
        "note": 0,
        "ok": 12
      },
...
```

### /badges/summary/:package

[![cran checks](https://cranchecks.info/badges/summary/reshape)](https://cranchecks.info/pkgs/reshape) `[![cran checks](https://cranchecks.info/badges/summary/reshape)](https://cranchecks.info/pkgs/reshape)`

### /badges/worst/:package

[![cran checks](https://cranchecks.info/badges/worst/reshape)](https://cranchecks.info/pkgs/reshape) `[![cran checks](https://cranchecks.info/badges/worst/reshape)](https://cranchecks.info/pkgs/reshape)`

### /badges/flavor/:flavor/:package

[![cran checks](https://cranchecks.info/badges/flavor/osx/additivityTests)](https://cranchecks.info/pkgs/additivityTests) `[![cran checks](https://cranchecks.info/badges/flavor/osx/additivityTests)](https://cranchecks.info/pkgs/additivityTests)`
