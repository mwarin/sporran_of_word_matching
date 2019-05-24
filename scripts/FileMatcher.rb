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
  def initialize (mode, *files)
    @files     = files;
    @matcher   = Matcher.new(mode);
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
      get_records(f) do |id, title, author|
        out_hash = {:id => id, :lookup_title => title, :results => []};
        results = @matcher.look_up_title(title, author);
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
  mode = {:min_score => ARGV.shift.to_i};
  FileMatcher.new(mode, *ARGV).run();
end
