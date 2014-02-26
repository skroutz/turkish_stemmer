require 'benchmark'
require 'turkish_stemmer'

Benchmark.bmbm(7) do |x|
  x.report('regex') do
    10000.times { "aaaaaaaaaa" =~ /^[#{TurkishStemmer::ALPHABET}]+$/ }
  end

  x.report('loop') do
    10000.times { "aaaaaaaaaa".chars.to_a.all? { |c| TurkishStemmer::ALPHABET.include?(c) } }
  end
end
