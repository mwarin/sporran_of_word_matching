require 'dotenv/load';
require 'mysql2';

=begin

Reads config from closest .env and sets up a MySQL connection.
.env must contain db_host, db_host, db_host, db_host, db_name.

=end

class Dbman
  Mysql2::Client.default_query_options.merge!(:symbolize_keys => true);
  attr_reader :dbh;
  def initialize      
    @dbh = Mysql2::Client.new(
      :host     => ENV['db_host'],
      :username => ENV['db_user'],
      :password => ENV['db_pw'  ],
      :port     => ENV['db_port'],
      :database => ENV['db_name'],
    );
  end
end

if $0 == __FILE__ then
  # Test / Example
  # $ bundle exec ruby scripts/Dbman.rb
  # $ 4
  dbh = Dbman.new.dbh;
  sth = dbh.prepare("SELECT 2+2 AS maths");
  res = sth.execute();
  res.each do |row|
    puts row[:maths];
  end
end
