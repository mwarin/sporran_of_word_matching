require_relative 'Matcher';
require 'json';

=begin

Adds file reading capability to Matcher.

From commandline:

$ bundle exec ruby scripts/FileMatcher.rb <limit 0.0-1.0> <list of files>

From code:

fm = FileMatcher.new(limit, *list_of_files);
fm.run();

=end

class FileMatcher
  def initialize (min_score, *files)
    @min_score = min_score;
    @files     = files;
    @matcher   = Matcher.new({:interactive=>false, :min_score=>@min_score});
  end

  # Inherit from FileMatcher.rb and override this method with custom file handler
  def get_records (f)
    fh = File.open(f, 'r');
    i = 0;
    fh.each_line do |line|
      i += 1;
      line.strip!
      yield i, line;
    end
    fh.close();
  end
  
  def run
    @files.each do |f|
      get_records(f) do |id, record|
        out_hash = {:id => id, :lookup_title => record, :results => []};
        results = @matcher.look_up_title(record);
        if !results.empty? then
          results.sort_by{|x| x[:score]}.each do |r|
            out_hash[:results] << r;
          end
        end
        puts out_hash.to_json;
      end
    end
  end  
end

if $0 == __FILE__ then
  min_score = ARGV.shift;
  FileMatcher.new(min_score.to_f, *ARGV).run();
end
