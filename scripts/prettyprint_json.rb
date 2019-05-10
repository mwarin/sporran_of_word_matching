require 'json';

ARGF.each do |arg|
  puts JSON.pretty_generate(
         JSON.parse(arg)
       );
end
