require 'benchmark'
require 'turkish_stemmer'
require 'lingua/stemmer'

Benchmark.bmbm(7) do |x|

  lingua_stemmer = Lingua::Stemmer.new(:language => "tr")

  x.report('Stem using turkish_stemmer gem') do
    1_000.times { TurkishStemmer.stem("telephonlar") }
  end

  x.report('Stem using ruby-stemmer gem') do
    1_000.times { lingua_stemmer.stem("telephonlar") }
  end
end
