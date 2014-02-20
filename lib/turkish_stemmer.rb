require "turkish_stemmer/version"
require "yaml"
require "hash_extension"
require "pry"

# @todo
#   * Generic last letter
#   * Merging vowel
#   * Drop pendings
#   * Add .stem
#   * Add states | suffixes
#   * Exceptions (evaluation phase)
#   * Add initial fixtures spec
#   * Check overstemming (size)

# Please note that we use only lowercase letters for all methods. One should
# normalize input streams.
module TurkishStemmer
  extend self

  $DEBUG = true

  ALPHABET   = "abcçdefgğhıijklmnoöprsştuüvyz"
  VOWELS     = "üiıueöao"
  CONSONANTS = "bcçdfgğhjklmnprsştvyz"
  ROUNDED_VOWELS    = "oöuü"
  UNROUNDED_VOWELS  = "iıea"
  FOLLOWING_ROUNDED_VOWELS = "aeuü"
  FRONT_VOWELS  = "eiöü"
  BACK_VOWELS   = "ıuao"

  def load_states_or_suffixes(file)
    YAML.load_file(file).symbolize_keys
  end

  NOMINAL_VERB_STATES   = load_states_or_suffixes("config/nominal_verb_states.yml")
  NOMINAL_VERB_SUFFIXES = load_states_or_suffixes("config/nominal_verb_suffixes.yml")

  NOUN_STATES   = load_states_or_suffixes("config/noun_states.yml")
  NOUN_SUFFIXES = load_states_or_suffixes("config/noun_suffixes.yml")

  PROTECTED_WORDS = begin
                      YAML.load_file("config/stemmer.yml")["protected_words"]
                    rescue => e
                      raise "please provide a valid config/stemmer.yml file, #{e}"
                    end

  # Counts syllabes of a Turkish word. In Turkish the number of syllables is
  # equals to the number of vowels.
  #
  # @param word [String] the word to count its syllables
  # @return [Fixnum] the number of syllables
  def count_syllables(word)
    vowels(word).size
  end

  # Gets vowels of a word
  #
  # @param word [String] the word to get vowels from
  # @return [Array] of vowels
  def vowels(word)
    word.gsub(/#{CONSONANTS.chars.join('|')}/,"").chars
  end

  # Checks vowel harmony of a word according to Turkish vowel harmony.
  #
  # @param word [String] the first vowel
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

  # Checks if a last 'y' consonant is formed by an affix formation or it is an
  # exception or a loanword. This method does not check if 'y' is the last char.
  #
  # @param word [String] the word to check for valid last y consonant
  # @return [Boolean]
  # @deprecated
  def valid_last_y_consonant?(word)
    word_chars    = word.chars
    previous_char = word_chars[-2]

    if VOWELS.include?(previous_char)
      true
    else
      false
    end
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

    if UNROUNDED_VOWELS.include?(vowel)
      if UNROUNDED_VOWELS.include?(candidate)
        return true
      end
    end

    if ROUNDED_VOWELS.include?(vowel)
      if FOLLOWING_ROUNDED_VOWELS.include?(candidate)
        return true
      end
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

    if FRONT_VOWELS.include?(vowel)
      if FRONT_VOWELS.include?(candidate)
        return true
      end
    end

    if BACK_VOWELS.include?(vowel)
      if BACK_VOWELS.include?(candidate)
        return true
      end
    end

    false
  end

  # Turkish stemmer
  #
  #
  def stem(word)
    # Pre-Process
    return word if !proceed_to_stem?(word)

    # Process
    stems = nominal_verbs_suffix_machine { word }.map do |nominal_word|
              noun_suffix_machine { nominal_word }
            end

    # Post-Process
    stem_post_process(stems, word)
  end

  # Checks whether a word can be stemmed or not.
  # This method checks word for nil, protected, length and harmory.
  #
  # @param word [String] the candidate word for stemming
  # @return [Boolean]
  def proceed_to_stem?(word)
    if word.nil? || PROTECTED_WORDS.include?(word) ||
      count_syllables(word) <= 1 || !has_vowel_harmony?(word)

      return false
    end

    true
  end

  # Post stemming process
  #
  # @param stems [Array] array of candidate stems
  # @param original_word [String] the original word we want to stem
  # @return [String] the stemmed word or original word
  def stem_post_process(stems, original_word)
    stems = stems.flatten.uniq

    # Reject all non-syllable words
    stems.reject! { |w| count_syllables(w) == 0 }

    # Reject orignal word
    stems.delete(original_word)

    # Transform last consonant word
    stems.map! { |word| last_consonant(word) }

    # Sort stems
    stems.sort!

    # Keep first or original word
    stems.empty? ? original_word : stems.first
  end

  def nominal_verbs_suffix_machine
    affix_morphological_stripper(yield, states: self::NOMINAL_VERB_STATES,
      suffixes: self::NOMINAL_VERB_SUFFIXES)
  end

  def noun_suffix_machine
    affix_morphological_stripper(yield, states: self::NOUN_STATES,
      suffixes: self::NOUN_SUFFIXES)
  end

  # A simple algorithm to strip suffixes from a word based on states and
  # transitions.
  #
  # @param word [String] the word to strip affixes from
  # @param options [Hash] options for the algorithm
  # @option options [Hash] :states The states and valid transitions
  # @option options [Hash] :suffixes The suffixes with their rules
  # @return [Array] all possible stem versions
  def affix_morphological_stripper(word, options = {})
    states   = options[:states]   || {}
    suffixes = options[:suffixes] || {}

    return [word] if states.nil?   || states.empty?
    return [word] if suffixes.nil? || suffixes.empty?

    stems    = []
    # Init first state pending transitions
    pendings = generate_pendings(:a, word, states)

    while !pendings.empty? do
      info    = pendings.shift
      word    = info[:word]
      suffix  = suffixes[info[:suffix]]
      to_state = states[info[:to_state]]
      answer    = mark_stem(word, suffix)

      if answer[:stem] == true
        if $DEBUG
          puts answer.to_s
        end

        if to_state[:final_state] == true
          # We have a valid transition here. It is safe to remove any pendings
          # with the same signature current pending
          remove_pendings_like(info, pendings)
          remove_mark_pendings(pendings)

          if to_state[:transitions].empty?
            # We are sure that this is a 100% final state
            stems.push answer[:word]
          else
            pendings.unshift(*generate_pendings(info[:to_state], answer[:word], states))
          end
        else
          mark_pendings(info, pendings)
          pendings.unshift(*generate_pendings(info[:to_state], answer[:word],
            states, rollback: info[:rollback], mark: true))
        end
      else
        if info[:rollback] && similar_pendings(info, pendings).empty?
          # unmark_pendings(pendings)
          stems.push info[:rollback]
        end
      end
    end

    return [word] if pendings.empty? && stems.empty?

    stems.uniq
  end

  # Given a state key and a word, scans through given states record to
  # generate valid pending transitions.
  #
  # @param key [String] the key for states hash
  # @param word [String] the word to check
  # @param states [Hash] the
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

  def remove_pendings_like(pending, array)
    array.reject! do |candidate|
      candidate[:to_state] == pending[:to_state] &&
      candidate[:from_state] == pending[:from_state]
    end
  end

  def mark_pendings(pending, array)
    array.select do |candidate|
      candidate[:to_state] == pending[:to_state] &&
      candidate[:from_state] == pending[:from_state]
    end.each do |candidate|
      candidate[:mark] = true
    end
  end

  def unmark_pendings(array)
    array.select do |candidate|
      candidate[:mark] == true
    end.each { |candidate| candidate[:mark] = false }
  end

  def remove_mark_pendings(array)
    array.reject! do |candidate|
      candidate[:mark] == true
    end
  end

  def similar_pendings(pending, array)
    array.select do |candidate|
      candidate[:to_state] == pending[:to_state] &&
      candidate[:from_state] == pending[:from_state]
    end
  end

  # Given a suffix it stems a word according to Turkish orthographic rules
  #
  # @param word [String] the word to stem
  # @param suffix [Hash] a suffix record
  # @return [Hash] a stem answer record
  def mark_stem(word, suffix)
    stem = (suffix[:check_harmony] && has_vowel_harmony?(word)) ||
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
  # @return [Array]
  def valid_optional_letter?(word, letter)
    match         = word.match(/#{letter}$/)
    answer        = true
    matched_char  = nil

    if match
      matched_char  = match.to_s
      previous_char = word[-2]

      answer = if VOWELS.include?(matched_char)
                 CONSONANTS.include?(previous_char)
               else
                 VOWELS.include?(previous_char)
               end
    end

    [answer, matched_char]
  end

  def last_consonant(word)
    consonants  = { 'b' => 'p', 'c' => 'ç', 'd' => 't', 'ğ' => 'k' }
    last_char   = word[-1]

    if consonants.keys.include?(last_char)
      word[-1] = consonants[last_char]
    end

    word
  end

  def test_stem(word)
    affix_morphological_stripper word,
      states: self::NOMINAL_VERB_STATES,
      suffixes: self::NOMINAL_VERB_SUFFIXES
  end
end
