require 'ruby_rhymes'
require 'raspell'
require 'engtagger'
require 'nokogiri'
require 'sinatra'
require 'cgi'
require 'sinatra/json'




def rhyme_line(line)
  words = line.split(/[\s\n]+/)
  result = words.map do |word|
    word.gsub(/[^\w\d]+/,'')
  end.reject do |word|
    word.strip.length.zero? || word =~ /[,'’]/
  end.map do |word|
    tagged = @tagger.add_tags(word)
    xml = Nokogiri::XML(tagged)
    part = xml.children.first.name
    is_blacklisted = !/^[vnj]/.match(part)

    if is_blacklisted
      word
    else

      syllables_to_match = word.to_phrase.syllables
      rhymes = word.to_phrase.flat_rhymes.select do |rhymed_word|
        rhymed_word.to_phrase.syllables == syllables_to_match
      end.select do |rhymed_word|
        suggestions = $speller.suggest(rhymed_word)
        is_spelled = rhymed_word.downcase == suggestions.first.downcase
      end
      rhymed = rhymes.sort_by do |rhyme|
        @words.find_index(rhyme) || 0
      end.first(10).sample


      rhymed || word
    end
  end.join(' ')
end

$speller = Aspell.new("en_US")
$speller.suggestion_mode = Aspell::NORMAL


get '/rhyme' do 
  @words = File.read('frequencies').lines
  @tagger = EngTagger.new

  q = JSON.parse(CGI.unescape(params['q']))['text']
  rhymed = q.lines.map do |line|
    rhyme_line(line)
  end.to_a.join("\n")


  json :rhymed => rhymed

end
