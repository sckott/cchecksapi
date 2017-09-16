## helper functions
def get_repo
  name = params[:name]
  fields = params[:fields] || '*'
  params.delete("fields")
  fields = check_fields(fields)

  # if name.nil?
  #   query = sprintf("SELECT %s FROM repos", fields)
  # else
  #   query = sprintf("SELECT %s FROM repos WHERE name = '%s'", fields, name)
  # end
  # return do_query(query)

  if name.nil?
    nms = pkg_names()
    tmp = []
    nms.each{ |x|
      tmp << concat_query(x, fields)
    }
    store = {"count" => tmp.length, "error" => nil, "data" => tmp}
    return JSON.generate(store)
  else
    # tables = ['repos','cran','cranlogs','github','appveyor']
    # tables = ['repos','cranlogs','github','appveyor']
    # out = {}
    # errors = {}
    # tables.each { |x|
    #   str = sprintf("SELECT %s FROM %s WHERE name = '%s'", fields, x, name)
    #   res = do_query_data(str)
    #   errors.store(x, res['error'])
    #   out.store(x, res['data'])
    # }
    out = concat_query(name, fields)
    # out["name"] = name
    store = {"count" => out.length, "error" => nil, "data" => out}
    return JSON.generate(store)
  end
end

def concat_query(name, fields)
  # tables = ['repos','cran','cranlogs','github','appveyor']
  tables = ['repos','cranlogs','github','appveyor']
  out = {}
  errors = {}
  tables.each { |x|
    if x == "repos"
      str = sprintf("SELECT %s FROM %s WHERE name = '%s'", fields, x, name)
    else
      str = sprintf("
        SELECT DISTINCT ON (a.inserted) %s
        FROM %s a
        WHERE name = '%s'
        ORDER BY a.inserted DESC
        LIMIT 1;",
        fields, x, name)
    end
    res = do_query_data(str)
    if x == 'repos'
      x = "metadata"
    end
    errors.store(x, res['error'])
    out.store(x, res['data'])
  }
  out["name"] = name
  return out
end

def get_repo_table(table)
  name = params[:name]
  fields = params[:fields] || '*'
  params.delete("fields")
  fields = check_fields(fields)
  str = sprintf("SELECT %s FROM %s WHERE name = '%s'", fields, table, name)
  res = do_query_data(str)
  return JSON.generate(res)
end

def get_repo_deps
  str = sprintf("SELECT * FROM cran WHERE name = '%s'", params[:name])
  res = do_query_data(str)
  res['data'][0] = res['data'][0].select { |k,v| k[/depends|imports|suggests|enhances/] }
  return JSON.generate(res)
end

def pkg_names
  pkgs1 = do_query_data("SELECT name FROM repos")['data']
  pkgs1.collect{ |x| x.values}.flatten
end

def do_query_data(query)
  res = $client.exec(query)
  out = res.collect{ |row| row }
  err = get_error(out)
  store = {"count" => out.length, "error" => err, "data" => out}
  return store
end

def add_repo
  name = params[:name]
  body = JSON.parse(request.body.read)
  body = add_missing(body)
  body["name"] = name
  keys = generate_keys(body.keys)
  # values = generate_values(body.values)
  values = body.values
  inserted = do_insert(values, keys)
  $client.exec("DEALLOCATE insert")
  return inserted
end

def add_missing(x)
  x["cran_archived"] = x["cran_archived"] || nil
  x["root"] = x["root"] || nil
  x["description"] = x["description"] || nil
  return x
end

def do_insert(x, keys)
  str = sprintf("INSERT INTO repos %s VALUES
    ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)", keys)
  $client.prepare('insert', str)
  $client.exec_prepared('insert', x)
end

def generate_keys(x)
  sprintf('(%s)', x.join(', '))
end

# def generate_values(x)
#   tmp = x.collect { |z|
#     if z.is_a? Numeric or !!z == z
#       z
#     else
#       sprintf("'%s'", z)
#     end
#   }
#   return tmp
#   # return sprintf('(%s)', tmp.join(', '))
# end

def edit_repo
  name = params[:name]
  body = JSON.parse(request.body.read)
  # body = add_missing(body)
  keys = generate_keys(body.keys)
  values = body.values
  # p keys
  # p values
  updated = do_update(name, keys, values)
  $client.exec("DEALLOCATE update")
  return updated
end

def do_update(name, keys, values)
  rep = (1..values.length).step(1).to_a
  repdoll = rep.collect{ |x| "$" + x.to_s }
  dolls = sprintf("(%s)", repdoll.join(', '))
  str = sprintf("UPDATE repos SET %s = %s WHERE name = '%s'", keys, dolls, name)
  $client.prepare('update', str)
  $client.exec_prepared('update', values)
end

def delete_repo
  return do_delete(params[:name])
end

def do_delete(x)
  tmp = JSON.parse(record_exists(x))
  if tmp["count"] == 0
    return { "deleted" => false, "message" => sprintf("%s record does not exist", x) }
  else
    str = sprintf("DELETE FROM repos WHERE name = '%s'", x)
    $client.exec(str)
    return { "deleted" => true, "message" => sprintf("%s record does not exist", x) }
  end
end

def record_exists(x)
  query = sprintf("SELECT name FROM repos WHERE name = '%s'", x)
  return do_query(query)
end

def check_fields(fields)
  query = sprintf("SELECT * FROM repos limit 1")
  res = $client.exec(query)
  flexist = res.fields
  fields = fields.split(',')
  if fields.length == 1
    fields = fields[0]
  end
  if fields.length == 0
    fields = '*'
  end
  if fields == '*'
    return fields
  else
    if fields.class == Array
      fields = fields.collect{ |d|
        if flexist.include? d
          d
        else
          nil
        end
      }
      fields = fields.compact.join(',')
      return fields
    else
      return fields
    end
  end
end

def do_query(query)
  res = $client.exec(query)
  out = res.collect{ |row| row }
  err = get_error(out)
  store = {"count" => out.length, "error" => err, "data" => out}
  return JSON.generate(store)
end

class Hash
  def compact
    delete_if { |k, v| v.nil? }
  end
end

def get_error(x)
  if x.length == 0
    return { 'message' => 'no results found' }
  else
    return nil
  end
end
