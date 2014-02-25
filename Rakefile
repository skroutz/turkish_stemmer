# coding: utf-8
require "bundler/gem_tasks"

desc "Update the stems of the sample words"
task :update_stemming_samples do
  require 'turkish_stemmer'
  words = []
  filename = "benchmarks/stemming_samples.txt"
  File.open(filename, "r") do |sample|
    while(line = sample.gets)
      word, _ = line.split(",")
      words << word
    end
  end

  File.open(filename, "w") do |sample|
    words.each do |word|
      sample.puts "#{word},#{TurkishStemmer.stem(word)}"
    end
  end
end
