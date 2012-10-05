$LOAD_PATH.unshift('./rethinkdb')
require 'rethinkdb.rb'
require 'test/unit'
$port_base = ARGV[0].to_i # 0 if none given
class DetTest < Test::Unit::TestCase
  include RethinkDB::Shortcuts
  def rdb
    @@c.use('test')
    r.table('tbl')
  end
  @@c = RethinkDB::Connection.new('localhost', $port_base + 12346)
  def c; @@c; end
  def server_data; rdb.orderby(:id).run.to_a; end

  def test__init
    begin
      r.db('test').create_table('tbl').run
    rescue
    end
    $data = (0...10).map{|x| {'id' => x}}
    rdb.delete.run
    rdb.insert($data).run
  end

  def test_det
    res = rdb.update{|row| {:count => r.js('0')}}.run
    assert_equal(res['errors'], 10); assert_not_nil(res['first_error'])
    assert_equal(server_data, $data)
    res = rdb.update{|row| {:count => 0}}.run
    assert_equal(res, {'updated'=>10, 'errors'=>0, 'skipped'=>0})

    res = rdb.mutate{|row| rdb.get(row[:id])}.run
    assert_equal(res['errors'], 10); assert_not_nil(res['first_error'])
    res = rdb.mutate{|row| row}.run

    res = rdb.update{{:count => rdb.map{|x| x[:count]}.reduce(0){|a,b| a+b}}}.run
    assert_equal(res['errors'], 10); assert_not_nil(res['first_error'])
    static = r.expr(server_data)
    res = rdb.update{{:count => static.map{|x| x[:id]}.reduce(0){|a,b| a+b}}}.run
    assert_equal(res, {'skipped'=>0, 'updated'=>10, 'errors'=>0})
  end

  def test_det_end
    assert_equal(rdb.map{|row| row[:count]}.reduce(0){|a,b| a+b}.run,
                 (rdb.map{|row| row[:id]}.reduce(0){|a,b| a+b} * rdb.length).run)
  end
end
