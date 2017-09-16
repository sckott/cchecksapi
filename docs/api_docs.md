# rOpenSci API

## Contents

* [Base url](#base-url)
* [HTTP methods](#http-methods)
* [Response codes](#response-codes)
* [Media types](#media-types)
* [Pagination](#pagination)
* [Authentication](#authentication)
* [Parameters](#parameters)
    * [Common parameters](#common-parameters)
    * [Additional parameters](#additional-parameters)
* [Routes](#routes)
    * [root](#root)
    * [heartbeat](#heartbeat)
    * [docs](#docs)
    * [repos](#repos)
    * [repo by name](#repo-by-name)
    * [historical data by repo by name](#historical-data-by-repo-by-name)

## Base URL

...coming soon

## HTTP methods

This is essentially a `read only` API. That is, we only allow `GET` (and `HEAD`) requests on this API.

Requests of all other types will be rejected with appropriate `405` code, including `POST`, `PUT`, `COPY`, `HEAD`, `DELETE`, etc.

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

* count: Number records found 
* returned: Number records returned
* error: If an error did not occur this is `null`, otherwise, an error message.
* data: The hash of data if any data returned. If no data found, this is an empty hash (hash of length zero)

## Media Types

We serve up only JSON in this API. All responses will have `Content-Type: application/json; charset=utf8`.

## Pagination

The query parameters `limit` (default = 10) and `offset` (default = 0) are always sent on the request (this doesn't apply to some routes, which don't accept any parameters (e.g., `/docs`)).

The response body from the server will include data on records found in `count` and number returned in `returned`:

* `"count": 1056`
* `"returned": 10`

Ideally, we'd put in a helpful [links object](http://jsonapi.org/format/#fetching-pagination) - hopefully we'll get that done in the future. 

## Authentication

We don't use any. Cheers :)

## Parameters

### Common parameters

+ limit (integer, optional) `number` of records to return.
    + Default: `10`
+ offset (integer, optional) Record `number` to start at.
    + Default: `0`
+ fields (string, optional) Comma-separated `string` of fieds to return.
    + Example: `SpecCode,Vulnerability`

Above parameters common to all routes except:

* [root](#root)
* [heartbeat](#heartbeat)
* [docs](#docs)
* [mysqlping](#mysqlping)

In addition, these do not support `limit` or `offset`:

* [listfields](#listfields)
 
### Additional parameters

Right now, any field that is returned from a route can also be queried on, except for the [/taxa route](#taxa), which only accepts `species` and `genus` in addition to the common parameters. All of the fields from each route are too long to list here - inspect data returned from a small data request, then change your query as desired.

Right now, parameters that are not found are silently dropped. For example, if you query with `/species?foo=bar` in a query, and `foo` is not a field in `species` route, then the `foo=bar` part is ignored. We may in the future error when parameters are not found.

## Routes

### root

> GET [/]

Get heartbeat for the Fishbase API [GET]

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
            [{
                "routes": [
                    "/docs/:table?",
                    "/heartbeat",
                    "/mysqlping",
                    "/comnames?<params>",
                    "/countref?<params>",
                    "/country?<params>",
                    "/diet?<params>",
                    "/ecology?<params>",
                    "/ecosystem?<params>",
                    ...
                ]
            }]
    ```

### docs

> GET [/docs]

Get brief description of each table in the Fishbase database. 

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### repos

> GET [/repos]

Get all repositories.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### repo by name

> GET [/repos/{repo_name}]

Get repository by name. This route by default gives data from the latest collection of all data sources. See `/repos/{name}/history` to get historical data.

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)

### historical data by repo by name

> GET [/repos/{repo_name}/history]

Get historical data from repository by name. This route default gives historical data from the latest collection going back through time. Default limit is 10 (that is, 10 days).

+ Response 200 (application/json)
    + [Headers](#response-headers)
    + [Body](#response-bodies)
