require 'es5'
{extend} = require 'lodash-fork'
require 'json-fork' # polyfill if JSON is missing
require 'debug-fork'
debug = global.debug 'ojson'

hasOwn = {}.hasOwnProperty

numSort = (a,b) ->
  c = +a
  d = +b
  if isFinite c
    if isFinite d
      c-d
    else
      false
  else if isFinite d
    true
  else
    a < b

# use of 'that' is to accommodate closurify

module.exports = class OJSON
  @useArrays = true

  @register: (constructors...) ->
    that = if this is global then OJSON else this

    for o in constructors
      if typeof o is 'object'
        for name,constructor of o
          debug "WARN: already registered [#{name}]" if that.registry[name]
          constructor['_ojson'] = name
          that.registry[name] = constructor
      else if o.name
        that.registry[o.name] = o
      else throw new Error("can't register anonymous types")
    return

  @unregister: (constructors...) ->
    that = if this is global then OJSON else this
    for o in constructors
      if typeof o is 'object'
        delete that.registry[k] for k of o
      else if typeof o is 'string'
        delete that.registry[o]
      else
        delete that.registry[o.name]
    return

  @stringify: (obj) ->
    that = if this is global then OJSON else this
    JSON.stringify that.toOJSON obj

  @toOJSON: (obj) ->
    that = if this is global then OJSON else this
    ret = that._toJSON obj if obj == ret = that._replacer '', obj
    ret

  @_toJSON: (obj) ->
    that = if this is global then OJSON else this
    return obj if obj == null or typeof obj != 'object'
    ret = if OJSON.useArrays and Array.isArray obj then [] else {}
    keys = Object.keys(obj)
    keys.sort(numSort)
    for k in keys
      v = obj[k]
      nv = that._replacer k, v
      if nv != v
        ret[k] = nv
        continue
      ret[k] = that._toJSON(v)
    ret

  @_replacer: (k, v) ->
    that = if this is global then OJSON else this
    return v if v == null or typeof v isnt 'object'
    n = v.constructor['_ojson'] || v.constructor.name
    if not that.registry[n]?
      return v['toOJSON']?() if v.constructor != Object
      return v
    return that._toJSON v if OJSON.useArrays and Array.isArray v
    doc = {}
    doc["$#{n}"] = if v.toJSON? then v.toJSON() else that._toJSON v
    doc

  @fromOJSON: (obj) ->
    that = if this is global then OJSON else this
    return obj if typeof obj isnt 'object' or obj == null

    res = if Array.isArray obj then [] else {}

    for k,v of obj
      v = that.fromOJSON v
      if k.charAt(0) is '$' and 'A' <= k.charAt(1) <= 'Z'
        if (constructor = that.registry[k.substr(1)])?
          if constructor.fromJSON?
            res = constructor.fromJSON obj=v
          else
            res = new constructor obj=v
          break
      res[k] = v

    res

  @parse: (str) ->
    that = if this is global then OJSON else this
    str && that.fromOJSON JSON.parse str

  @registry = {}

  @copyKeys =
    fromJSON: (obj) ->
      inst = new this
      inst[k] = v for k,v of obj
      inst

  register: @register
  unregister: @unregister
  stringify: @stringify
  fromOJSON: @fromOJSON
  toOJSON: @toOJSON
  _toJSON: @_toJSON
  _replacer: @_replacer
  parse: @parse

  constructor: ->
    @useArrays = OJSON.useArrays
    @registry = Object.create OJSON.registry

OJSON.register Date, Array
extend Array, OJSON.copyKeys
