# Copyright 2010-2012 RethinkDB, all rights reserved.
module RethinkDB
  # A database stored on the cluster.  Usually created with the <b>+r+</b>
  # shortcut, like:
  #   r.db('test')
  class Database
    # Refer to the database named <b>+name+</b>.  Usually you would
    # use the <b>+r+</b> shortcut instead:
    #   r.db(name)
    def initialize(name); @db_name = name.to_s; end

    # Access the table <b>+name+</b> in this database.  For example:
    #   r.db('test').table('tbl')
    # May also provide a set of options OPTS.  Right now the only
    # useful option is :use_outdated:
    #   r.db('test').table('tbl', {:use_outdated => true})
    def table(name, opts={}); Table.new(@db_name, name, opts); end

    # Create a new table in this database.  You may also optionally
    # specify the datacenter it should reside in, its primary key, and
    # its cache size.  For example:
    #   r.db('db').create_table('tbl', {:datacenter  => 'dc',
    #                                   :primary_key => 'id',
    #                                   :cache_size  => 1073741824})
    # When run, either returns <b>+nil+</b> or throws on error.
    def create_table(name, optargs={})
      S.check_opts(optargs, [:datacenter, :primary_key, :cache_size])
      dc = optargs[:datacenter] || S.skip
      pkey = optargs[:primary_key] || S.skip
      cache = optargs[:cache_size] || S.skip
      B.alt_inspect(Meta_Query.new [:create_table, dc, [@db_name, name], pkey, cache]) {
        "db(#{@db_name.inspect}).create_table(#{name.inspect})"
      }
    end

    # Drop the table <b>+name+</b> from this database.  When run,
    # either returns <b>+nil+</b> or throws on error.
    def drop_table(name)
      B.alt_inspect(Meta_Query.new [:drop_table, @db_name, name]) {
        "db(#{@db_name.inspect}).drop_table(#{name.inspect})"
      }
    end

    # List all the tables in this database.  When run, either returns
    # <b>+nil+</b> or throws on error.
    def list_tables
      B.alt_inspect(Meta_Query.new [:list_tables, @db_name]) {
        "db(#{@db_name.inspect}).list_tables"
      }
    end

    def inspect # :nodoc:
      real_inspect({:str => @db_name})
    end
  end

  # A table in a particular RethinkDB database.  If you call a
  # function from Sequence on it, it will be treated as a
  # Stream_Expression reading from the table.
  class Table
    def inspect # :nodoc:
      to_mrs.inspect
    end

    attr_accessor :opts
    # A table named <b>+name+</b> residing in database <b>+db_name+</b>.
    def initialize(db_name, name, opts)
      @db_name = db_name;
      @table_name = name;
      @opts = opts
      @context = caller
      S.check_opts(@opts, [:use_outdated])
      use_od = (@opts.include? :use_outdated) ? @opts[:use_outdated] : S.conn_outdated
      @body = [:table, @db_name, @table_name, use_od]
    end

    # Insert one or more rows into the table.  For example:
    #   table.insert({:id => 0})
    #   table.insert([{:id => 1}, {:id => 2}])
    # If you try to insert a
    # row with a primary key already in the table, you will get back
    # an error.  For example, if you have a table <b>+table+</b>:
    #   table.insert([{:id => 1}, {:id => 1}])
    # Will return something like:
    #   {'inserted' => 1, 'errors' => 1, 'first_error' => ...}
    # If you want to overwrite a row, you should set <b>+mode+</b> to
    # <b>+:upsert+</b>, like so:
    #   table.insert([{:id => 1}, {:id => 1}], :upsert)
    # which will return:
    #   {'inserted' => 2, 'errors' => 0}
    # You may also provide a stream.  So to make a copy of a table, you can do:
    #   r.create_db('new_db').run
    #   r.db('new_db').create_table('new_table').run
    #   r.db('new_db').new_table.insert(table).run
    def insert(rows, mode=:new)
      raise_if_outdated
      rows = [rows] if rows.class != Array
      do_upsert = (mode == :upsert ? true : false)
      Write_Query.new [:insert, [@db_name, @table_name], rows.map{|x| S.r(x)}, do_upsert]
    end

    # Get the row of the invoking table with key <b>+key+</b>.  You may also
    # optionally specify the name of the attribute to use as your key
    # (<b>+keyname+</b>), but note that your table must be indexed by that
    # attribute.  For example, if we have a table <b>+table+</b>:
    #   table.get(0)
    def get(key, keyname=:id)
      Single_Row_Selection.new [:getbykey, [@db_name, @table_name], keyname, S.r(key)]
    end

    def method_missing(m, *args, &block) # :nodoc:
      to_mrs.send(m, *args, &block);
    end

    def to_mrs # :nodoc:
      B.alt_inspect(Multi_Row_Selection.new(@body, @context, @opts)) {
        "db(#{@db_name.inspect}).table(#{@table_name.inspect})"
      }
    end
  end
end
