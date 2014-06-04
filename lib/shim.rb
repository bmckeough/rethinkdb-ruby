module RethinkDB
  require 'json'
  require 'time'
  module Shim
    def self.recursive_munge(x, parse_time, parse_group)
      case x
      when Hash
        if parse_time && x['$reql_type$'] == 'TIME'
          t = Time.at(x['epoch_time'])
          tz = x['timezone']
          return (tz && tz != "" && tz != "Z") ? t.getlocal(tz) : t.utc
        elsif parse_group && x['$reql_type$'] == 'GROUPED_DATA'
          return Hash[x['data']]
        else
          x.each {|k, v|
            v2 = recursive_munge(v, parse_time, parse_group)
            x[k] = v2 if v.object_id != v2.object_id
          }
        end
      when Array
        x.each_with_index {|v, i|
          v2 = recursive_munge(v, parse_time, parse_group)
          x[i] = v2 if v.object_id != v2.object_id
        }
      end
      return x
    end

    def self.load_json(target, opts={})
      res = JSON.parse(target, opts)
      recursive_munge(JSON.parse(target),
                      opts[:time_format] != 'raw',
                      opts[:group_format] != 'raw')
    end

    def self.dump_json(*a, &b)
      JSON.generate(*a, &b)
    end

    def self.response_to_native(r, orig_term, opts)
      rt = Response::ResponseType
      begin
        case r['t']
        when rt::SUCCESS_ATOM     then r['r'][0]
        when rt::SUCCESS_FEED     then r['r']
        when rt::SUCCESS_PARTIAL  then r['r']
        when rt::SUCCESS_SEQUENCE then r['r']
        when rt::RUNTIME_ERROR    then raise RqlRuntimeError, r['r'][0]
        when rt::COMPILE_ERROR    then raise RqlCompileError, r['r'][0]
        when rt::CLIENT_ERROR     then raise RqlDriverError,  r['r'][0]
        else raise RqlRuntimeError, "Unexpected response: #{r.inspect}"
        end
      rescue RqlError => e
        raise e.class, "#{e.message}\nBacktrace:\n#{RPP.pp(orig_term, r['b'])}"
      end
    end
  end

  class RQL
    def to_json(*a, &b)
      @body.to_json(*a, &b)
    end
    def to_pb; @body; end

    def self.safe_to_s(x)
      case x
      when String then x
      when Symbol then x.to_s
      else raise RqlDriverError, 'Object keys must be strings or symbols.  '+
          "(Got object `#{x.inspect}` of class `#{x.class}`.)"
      end
    end

    def self.fast_expr(x, max_depth)
      if max_depth == 0
        raise RqlDriverError, "Maximum expression depth exceeded " +
          "(you can override this with `r.expr(X, MAX_DEPTH)`)."
      end
      case x
      when RQL then x
      when Array then RQL.new([Term::TermType::MAKE_ARRAY,
                               x.map{|y| fast_expr(y, max_depth-1)}])
      when Hash then RQL.new(Hash[x.map{|k,v| [safe_to_s(k),
                                               fast_expr(v, max_depth-1)]}])
      when Proc then RQL.new.new_func(&x)
      when String then RQL.new(x)
      when Symbol then RQL.new(x)
      when Numeric then RQL.new(x)
      when FalseClass then RQL.new(x)
      when TrueClass then RQL.new(x)
      when Time then
        epoch_time = x.to_f
        offset = x.utc_offset
        raw_offset = offset.abs
        raw_hours = raw_offset / 3600
        raw_minutes = (raw_offset / 60) - (raw_hours * 60)
        tz = (offset < 0 ? "-" : "+") + sprintf("%02d:%02d", raw_hours, raw_minutes);
        RQL.new({ '$reql_type$' => 'TIME',
                  'epoch_time'  => epoch_time,
                  'timezone'    => tz })
      else raise RqlDriverError, "r.expr can't handle #{x.inspect} of class #{x.class}."
      end
    end

    def expr(x, max_depth=20)
      unbound_if(@body != RQL)
      RQL.fast_expr(x, max_depth)
    end
    def coerce(other)
      [RQL.new.expr(other), self]
    end
  end
end
