# cran checks API

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
    * [pkgs](#pkgs)
    * [pkg by name](#pkg-by-name)

## Base URL

<https://cranchecks.info>

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
Access-Control-Allow-Methods: HEAD, GET
Access-Control-Allow-Origin: *
Cache-Control: public, must-revalidate, max-age=60
Connection: close
Content-Length: 10379
Content-Type: application/json; charset=utf8
Date: Mon, 09 Mar 2015 23:01:23 GMT
Server: nginx/1.7.10
Status: 200 OK
X-Content-Type-Options: nosniff
```

### Response bodies

Response bodies generally look like:

```
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

Above parameters can be used only on `/pkgs`

## Routes

### root

> GET [/]

Get heartbeat for the cranchecks API [GET]

This path redirects to `/heartbeat`

+ Response 302 (application/json)

        See `/heartbeat`

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

### pkgs

> GET [/pkgs]

Get all repositories.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### pkg by name

> GET [/pkgs/{package_name}]

Get package by name.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)
