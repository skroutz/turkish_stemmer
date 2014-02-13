require "turkish_stemmer/version"
require "pry"

# Please note that we use only lowercase letters for all methods. One should
# normalize input streams.
module TurkishStemmer
  extend self

  ALPHABET   = "abcçdefgğhıijklmnoöprsştuüvyz"
  VOWELS     = "üiıueöao"
  CONSONANTS = "bcçdfgğhjklmnprsştvyz"
  ROUNDED_VOWELS    = "oöuü"
  UNROUNDED_VOWELS  = "iıea"
  FOLLOWING_ROUNDED_VOWELS = "aeuü"
  FRONT_VOWELS  = "eiöü"
  BACK_VOWELS   = "ıuao"

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
      info    = pendings.pop
      word    = info[:word]
      suffix  = suffixes[info[:suffix]]
      to_state = states[info[:to_state]]
      answer    = mark_stem(word, suffix)

      if answer[:stem] == true
        if to_state[:final_state] == true
          if to_state[:transitions].empty?
            # We are sure that this is a 100% final state
            stems.push answer[:word]
          else
            pendings += generate_pendings(info[:from_state], answer[:word], states)
          end
        else
          pendings += generate_pendings(info[:from_state], answer[:word],
            states, rollback: info[:rollback])
        end
      else
        if info[:rollback]
          stems.push info[:rollback]
        end
      end
    end

    return [word] if pendings.empty? && stems.empty?
    stems
  end

  # Given a state_key and a word, scan through a given states record to generate
  # valid pending transitions.
  #
  # @param key [String] the key for states hash
  # @param word [String] the word to check
  # @param states [Hash] the
  def generate_pendings(key, word, states, options = {})
    raise ArgumentError, "State #{key} does not exist" if (state = states[key]).nil?
    rollback = options[:rollback]
    rollback ||= state[:final_state] ? word : nil

    state[:transitions].map do |transition|
      {
        suffix: transition[:suffix],
        to_state: transition[:state],
        from_state: :a,
        word: word,
        rollback: rollback
      }
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

      if suffix[:extra_y_consonant] && "yY".include?(new_word.chars.last)
        if valid_last_y_consonant?(new_word)
          new_word = new_word.chop
          suffix_applied = 'y' + suffix_applied
        else
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


  def check(word)
    regex_suffix_removal(word, states: NOMINAL_VERB_STATES,
      suffixes: NOMINAL_VERB_SUFFIXES)
  end
end
