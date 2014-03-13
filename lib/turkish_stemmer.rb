# coding: utf-8
require "turkish_stemmer/version"
require "yaml"
require "hash_extension"
require "pry"

# Please note that we use only lowercase letters for all methods. One should
# normalize input streams before using the `stem` method.
module TurkishStemmer
  extend self


  VOWELS                    = "üiıueöao"
  CONSONANTS                = "bcçdfgğhjklmnprsştvyz"
  ROUNDED_VOWELS            = "oöuü"
  UNROUNDED_VOWELS          = "iıea"
  FOLLOWING_ROUNDED_VOWELS  = "aeuü"
  FRONT_VOWELS              = "eiöü"
  BACK_VOWELS               = "ıuao"

  # Heuristic size for average Turkish stemmed word size
  AVG_STEMMED_SIZE          = 4

  # Regular expression that checks if the word contains only turkish characters
  ALPHABET = Regexp.new("^[abcçdefgğhıijklmnoöprsştuüvyz]+$").freeze

  # Stems a Turkish word.
  #
  # Algorithm consists of 3 parts: pre-process, process and post-process. The
  # pre-process phase is a quick lookup for words that should not be stemmed
  # based on length, protected words list and vowel harmony. The process phase
  # includes a nominal verb suffix and a noun suffix stripper machine. The last
  # phase includes some additional checks and a simple stem selection decision.
  #
  # @param word [String] the word to stem
  # @return [String] the stemmed word
  def stem(original_word)
    # Preprocess
    return original_word if !proceed_to_stem?(original_word)

    word = original_word.dup

    # Process
    stems = nominal_verbs_suffix_machine { word }.map do |nominal_word|
              noun_suffix_machine { nominal_word }.map do |noun_word|
                derivational_suffix_machine { noun_word }
              end
            end

    # Postprocess
    stem_post_process(stems, original_word)
  end

  # Loads yaml file and symbolizes keys
  #
  # @param file [String] path to yaml file
  # @return [Hash] the hash with symbols as keys
  def load_states_or_suffixes(file)
    config_path = File.expand_path("../../#{file}", __FILE__)

    YAML.load_file(config_path).symbolize_keys
  rescue => e
    raise "An error occured loading #{file}, #{e}"
  end

  # Helper method for loading settings
  #
  # @param key [String] the key
  def load_settings(key)
    config_path = File.expand_path("../../config/stemmer.yml", __FILE__)

    begin
      YAML.load_file(config_path)[key]
    rescue => e
      raise "Please provide a valid config/stemmer.yml file, #{e}"
    end
  end

  NOMINAL_VERB_STATES   = load_states_or_suffixes("config/nominal_verb_states.yml")
  NOMINAL_VERB_SUFFIXES = load_states_or_suffixes("config/nominal_verb_suffixes.yml")

  NOUN_STATES   = load_states_or_suffixes("config/noun_states.yml")
  NOUN_SUFFIXES = load_states_or_suffixes("config/noun_suffixes.yml")

  DERIVATIONAL_STATES = load_states_or_suffixes("config/derivational_states.yml")
  DERIVATIONAL_SUFFIXES = load_states_or_suffixes("config/derivational_suffixes.yml")

  ##
  # Load settings
  #
  # Protected words
  PROTECTED_WORDS = load_settings("protected_words")

  # Last consonant exceptions
  LAST_CONSONANT_EXCEPTIONS = load_settings("last_consonant_exceptions")

  # Vower harmony exceptions
  VOWEL_HARMONY_EXCEPTIONS = load_settings("vowel_harmony_exceptions")

  # Counts syllables of a Turkish word. In Turkish the number of syllables is
  # equals to the number of vowels.
  #
  # @param word [String] the word to count its syllables
  # @return [Fixnum] the number of syllables
  def count_syllables(word)
    vowels(word).size
  end

  # Gets the vowels of a word
  #
  # @param word [String] the word to get its vowels
  # @return [Array] array of vowels
  def vowels(word)
    word.gsub(/#{CONSONANTS.chars.to_a.join('|')}/,"").chars.to_a
  end

  # Checks vowel harmony of a word according to Turkish vowel harmony.
  #
  # @param word [String] the word to be checked against Turkish vowel harmony
  # @return [Boolean]
  # @see https://en.wikipedia.org/wiki/Vowel_harmony#Turkish
  def has_vowel_harmony?(word)
    word_vowels = vowels(word)
    vowel       = word_vowels[-2]
    candidate   = word_vowels[-1]

    vowel_harmony?(vowel, candidate)
  end

  # Checks vowel harmony between two vowels
  #
  # @param vowel [String] the first vowel
  # @param candidate [String] the second vowel
  # @return [Boolean]
  # @see https://en.wikipedia.org/wiki/Vowel_harmony#Turkish
  def vowel_harmony?(vowel, candidate)
    has_roundness?(vowel, candidate) && has_frontness?(vowel, candidate)
  end

  # Checks roundness vowel harmony of two vowels according to Turkish vowel
  # harmony.
  #
  # @param vowel [String] the first vowel
  # @param candidate [String] the second vowel
  # @return [Boolean]
  # @see https://en.wikipedia.org/wiki/Vowel_harmony#Turkish
  def has_roundness?(vowel, candidate)
    return true if vowel.nil? || vowel.empty?
    return true if candidate.nil? || candidate.empty?

    if (UNROUNDED_VOWELS.include?(vowel) && UNROUNDED_VOWELS.include?(candidate)) ||
       (ROUNDED_VOWELS.include?(vowel) && FOLLOWING_ROUNDED_VOWELS.include?(candidate))
      return true
    end

    false
  end

  # Checks frontness vowel harmony of two vowels according to Turkish vowel
  # harmony.
  #
  # @param vowel [String] the first vowel
  # @param candidate [String] the second vowel
  # @return [Boolean]
  # @see https://en.wikipedia.org/wiki/Vowel_harmony#Turkish
  def has_frontness?(vowel, candidate)
    return true if vowel.nil? || vowel.empty?
    return true if candidate.nil? || candidate.empty?

    if (FRONT_VOWELS.include?(vowel) && FRONT_VOWELS.include?(candidate)) ||
       (BACK_VOWELS.include?(vowel) && BACK_VOWELS.include?(candidate))
      return true
    end

    false
  end

  # Checks whether a word can be stemmed or not. This method checks candidate
  # word against nil, protected, length and vowel harmory.
  #
  # @param word [String] the candidate word for stemming
  # @return [Boolean] whether should proceed to stem or not
  def proceed_to_stem?(word)
    if word.nil? || !turkish?(word) ||
      PROTECTED_WORDS.include?(word) ||
      count_syllables(word) <= 1 ||
      (!has_vowel_harmony?(word) && !VOWEL_HARMONY_EXCEPTIONS.include?(word))

      return false
    end

    true
  end

  # Post stemming process
  #
  # @param   stems          [Array]   array of candidate stems
  # @param   original_word  [String]  the original word
  # @return                 [String]  the stemmed or the original word
  def stem_post_process(stems, original_word)
    if ENV['DEBUG']
      puts "post process for #{original_word}: #{stems}"
    end

    stems = stems.flatten.uniq

    # Reject all non-syllable words
    stems.reject! { |w| count_syllables(w) == 0 }

    # Transform last consonant
    stems.map! { |word| last_consonant!(word) }

    # Sort stems by size
    stems.sort! do |x,y|
      (x.size -  AVG_STEMMED_SIZE).abs <=> (y.size - AVG_STEMMED_SIZE).abs
    end

    # Keep first or original word
    stems.empty? ? original_word : stems.first
  end

  # Given a state key and a word, scans through given states and generate valid
  # pending transitions.
  #
  # @param key [String] the key for states hash
  # @param word [String] the word to check
  # @param states [Hash] the states hash
  # @param options [Hash] options for pendings
  # @option options [Boolean] :mark Whether this pending is marked for deletion
  # @option options [String] :rollback The rollback string
  # @return [Array] array of pendings
  def generate_pendings(key, word, states, options = {})
    raise ArgumentError, "State #{key} does not exist" if (state = states[key]).nil?
    rollback = options[:rollback]
    rollback ||= state[:final_state] ? word : nil
    mark = options[:mark] || false

    state[:transitions].map do |transition|
      {
        suffix: transition[:suffix],
        to_state: transition[:state],
        from_state: key,
        word: word,
        rollback: rollback,
        mark: mark
      }
    end
  end

  # Given a suffix it stems a word according to Turkish orthographic rules
  #
  # @param word [String] the word to stem
  # @param suffix [Hash] a suffix record
  # @return [Hash] a stem answer record
  def mark_stem(word, suffix)
    stem = !PROTECTED_WORDS.include?(word) &&
           (suffix[:check_harmony] &&
           (has_vowel_harmony?(word)) || VOWEL_HARMONY_EXCEPTIONS.include?(word)) ||
           !suffix[:check_harmony]

    suffix_applied = suffix[:regex]

    if stem && (match = word.match(/(#{suffix_applied})$/))
      new_word = word.gsub(/(#{match.to_s})$/, '')
      suffix_applied = match.to_s

      if suffix[:optional_letter]
        answer, match = valid_optional_letter?(new_word, suffix[:optional_letter])

        if answer && match
          new_word = new_word.chop
          suffix_applied = match + suffix_applied
        elsif !answer
          new_word = word
          suffix_applied = nil
          stem = false
        end
      end
    else
      stem = false
      suffix_applied = nil
      new_word = word
    end

    { stem: stem, word: new_word, suffix_applied: suffix_applied }
  end

  # Given a word and a letter it checks if the optional letter can be part of
  # the stem or not.
  #
  # @param word [String] the examined word
  # @param letter [String] a single letter or a string armed with a regular
  #   expression
  # @return [Array] the answer is returned as an array. First element is a
  #   Boolean value and second element is the mached character.
  # @example
  #   self.valid_optional_letter?("test", "t")
  #   # => [true, 't']
  def valid_optional_letter?(word, letter)
    match         = word.match(/#{letter}$/)
    answer        = true
    matched_char  = nil

    if match
      matched_char  = match.to_s
      previous_char = word[-2]

      answer = if VOWELS.include?(matched_char)
                 (previous_char && CONSONANTS.include?(previous_char))
               else
                 (previous_char && VOWELS.include?(previous_char))
               end
    end

    [answer, matched_char]
  end

  # Transforms a word taken into account last consonant rule.
  #
  # @param word [String] the word to check for last consonant change
  # @return [String] the changed word
  def last_consonant!(word)
    return word if LAST_CONSONANT_EXCEPTIONS.include?(word)

    consonants  = { 'b' => 'p', 'c' => 'ç', 'd' => 't', 'ğ' => 'k' }
    last_char   = word[-1]

    if consonants.keys.include?(last_char)
      word[-1] = consonants[last_char]
    end

    word
  end

  # Helper method. This is just a shortcut.
  def nominal_verbs_suffix_machine
    affix_morphological_stripper(yield, states: self::NOMINAL_VERB_STATES,
      suffixes: self::NOMINAL_VERB_SUFFIXES)
  end

  # Helper method. This is just a shortcut.
  def noun_suffix_machine
    affix_morphological_stripper(yield, states: self::NOUN_STATES,
      suffixes: self::NOUN_SUFFIXES)
  end

  # Helper method
  def derivational_suffix_machine
    affix_morphological_stripper(yield, states: self::DERIVATIONAL_STATES,
      suffixes: self::DERIVATIONAL_SUFFIXES)
  end

  # A simple algorithm to strip suffixes from a word based on states and
  # transitions.
  #
  # @param  word    [String]  the word to strip affixes from
  # @param  options [Hash]    options for the algorithm
  # @option options [Hash]    :states The states and valid transitions
  # @option options [Hash]    :suffixes The suffixes with their rules
  # @return         [Array]   all possible stem versions
  def affix_morphological_stripper(word, options = {})
    states   = options[:states]   || {}
    suffixes = options[:suffixes] || {}

    return [word] if states.nil?   || states.empty?
    return [word] if suffixes.nil? || suffixes.empty?

    stems    = []
    # Init first state pending transitions
    pendings = generate_pendings(:a, word, states)

    while !pendings.empty? do
      info      = pendings.shift
      word      = info[:word]
      suffix    = suffixes[info[:suffix]]
      to_state  = states[info[:to_state]]
      answer    = mark_stem(word, suffix)

      if answer[:stem] == true
        if ENV['DEBUG']
          puts "Word: #{word} \nAnswer: #{answer} \nInfo: #{info} \nSuffix: #{suffix}"
        end

        if to_state[:final_state] == true
          # We have a valid transition here. It is safe to remove any pendings
          # with the same signature current pending
          # binding.pry
          remove_pendings_like!(info, pendings)
          remove_mark_pendings!(pendings)

          if to_state[:transitions].empty?
            # We are sure that this is a 100% final state
            stems.push answer[:word]
          else
            pendings.unshift(*generate_pendings(info[:to_state], answer[:word], states))
          end
        else
          mark_pendings!(info, pendings)
          pendings.unshift(*generate_pendings(info[:to_state], answer[:word],
            states, rollback: info[:rollback], mark: true))
        end
      else
        if info[:rollback] && similar_pendings(info, pendings).empty?
          # unmark_pendings!(pendings)
          stems.push info[:rollback]
        end
      end
    end

    return [word] if pendings.empty? && stems.empty?

    stems.uniq
  end

  private

  def remove_pendings_like!(pending, array)
    array.reject! do |candidate|
      candidate[:to_state] == pending[:to_state] &&
      candidate[:from_state] == pending[:from_state]
    end
  end

  def mark_pendings!(pending, array)
    similar_pendings(pending, array).each do |candidate|
      candidate[:mark] = true
    end
  end

  def unmark_pendings!(array)
    array.select do |candidate|
      candidate[:mark] == true
    end.each { |candidate| candidate[:mark] = false }
  end

  def remove_mark_pendings!(array)
    array.reject! { |candidate| candidate[:mark] == true }
  end

  def similar_pendings(pending, array)
    array.select do |candidate|
      candidate[:to_state] == pending[:to_state] &&
      candidate[:from_state] == pending[:from_state]
    end
  end

  def turkish?(word)
    !! word.match(ALPHABET)
  end

end
