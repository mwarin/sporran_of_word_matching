# coding: utf-8
require 'i18n';
I18n.available_locales = [:en];

class Strutil
  @@latin_common_rx   = Regexp.new(/\p{Latin}|\p{Common}/);
  @@common_non_num_rx = Regexp.new(/[\p{Common}&&[^0-9]]/);

  # get_words("1789-1795. La Révolution à Dijon.")
  # -> %w[1789 1795 la revolution a dijon]
  def Strutil.get_words (str)
    str.downcase.split(@@common_non_num_rx).map{|x| translit_if_possible(x)}.uniq.reject{|x| x == '' || x =~ /\s/};
  end

  # translit_if_possible("révolution") -> "revolution"
  # does nothing on non-locale strings
  def Strutil.translit_if_possible (str)
    translit = I18n.transliterate(str).gsub(/\?+/, '');
    if translit == '' then
      return str;
    end
    return translit;
  end
  
end
