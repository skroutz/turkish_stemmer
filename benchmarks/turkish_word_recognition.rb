require 'benchmark'
require 'turkish_stemmer'

Benchmark.bmbm(7) do |x|

  x.report('regex') do
    TurkishStemmer.class_eval do
      def self.turkish?(word)
        !! word.match(TurkishStemmer::ALPHABET)
      end
    end

    100_000.times { TurkishStemmer.turkish?("aaa") }
  end

  x.report('loop') do
    TurkishStemmer.class_eval do
      def self.turkish?(word)
        !! word.chars.to_a.all? { |c| "abcçdefgğhıijklmnoöprsştuüvyz".include?(c) }
      end
    end

    100_000.times { TurkishStemmer.turkish?("aaaa") }
  end
end
