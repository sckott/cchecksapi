  def route(table, var)
    key = rediskey(table, params)
    if redis_exists(key)
      obj = get_cached(key)
      if obj.nil?
        obj = get_new_ids(key, table, var, params)
      end
    else
      obj = get_new_ids(key, table, var, params)
    end
    return give_data(obj)
  end

  def get_args(x, prefix=false)
    if prefix
      res = x.collect{ |row| "s.%s = '%s'" % row }
    else
      res = x.collect{ |row| "%s = '%s'" % row }
    end
    if res.length == 0
      return ''
    else
      return "WHERE " + res.join(' AND ')
    end
  end

  def check_params(table, params)
    if params.length == 0
      return params
    else
      query = sprintf("SELECT * FROM %s limit 1", table)
      res = $client.query(query, :as => :json)
      flexist = ["^", res.fields.join('$|^'), "$"].join('').downcase
      params = params.keep_if { |key, value| key.downcase.to_s.match(flexist) }
      return params
    end
  end

  def check_max(x, max)
    if x.to_i > max
      halt 400, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'invalid request', 'message' => sprintf('maximum limit is %d', max)})
    end
  end

  def check_class(x, param)
    mm = x.match(/[a-zA-Z]+/)
    if !mm.nil?
      halt 400, {'Content-Type' => 'application/json'}, JSON.generate({ 'error' => 'invalid request', 'message' => sprintf('%s must be an integer', param)})
    end
  end

  def check_hang_equal(x, default)
    if x == ""
      return default
    else
      return x
    end
  end

  def give_data(obj)
    data = { "count" => obj['count'], "returned" => obj['data'].length, "error" => obj['error'], "data" => obj['data'] }
    return JSON.pretty_generate(data)
  end

  def get_count(table, string)
    query = sprintf("SELECT count(*) as ct FROM %s %s", table, string)
    res = $client.query(query, :as => :json)
    res.collect{ |row| row }[0]["ct"]
  end
