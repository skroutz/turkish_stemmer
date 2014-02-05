require "turkish_stemmer/version"

module TurkishStemmer
  extend self

  ALPHABET = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZabcçdefgğhıijklmnoöprsştuüvyz"
  VOWELS = "üiıueöaoAEIİOÖUÜ"
  CONSONANTS = "BCÇDFGĞHJKLMNPRSŞTVYZbcçdfgğhjklmnprsştvyz"
  ROUNDED_VOWELS = "oöuüOÖUÜ"
  UNROUNDED_VOWELS = "iıeaAEIİ"
  FOLLOWING_ROUNDED_VOWELS = "aeuüAEUÜ"
  FRONT_VOWELS = "eiöüEİÖÜ"
  BACK_VOWELS = "ıuaoAIOU"

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

  NOMINAL_VERB_STATES =
  {
    0 =>
    {
      transitions:
      [
        { suffix: 1,  state: 1 },
        { suffix: 2,  state: 1 },
        { suffix: 3,  state: 1 },
        { suffix: 4,  state: 1 },
        { suffix: 5,  state: 2 },
        { suffix: 12, state: 3 },
        { suffix: 13, state: 3 },
        { suffix: 14, state: 3 },
        { suffix: 15, state: 3 },
      ],

      final_state: false
     }
  }


  NOMINAL_VERB_SUFFIXES =
  {
    1 =>
    {
      name: "-(y)Um",
      regex: "um",
      extra_y_consonant: true,
      check_harmony: true
    },

    2 =>
    {
      name: "-sUn",
      extra_y_consonant: false,
      check_harmony: true
    },

    3 =>
    {
      name: "-(y)Uz",
      extra_y_consonant: true,
      check_harmony: true
    },

    4 =>
    {
      name: "-sUnUz",
      extra_y_consonant: true,
      check_harmony: true
    },

    5 =>
    {
      name: "-lAr",
      extra_y_consonant: true,
      check_harmony: false
    }
  }


  # A simple algorithm to strip suffixes from a word based on states and
  # transitions.
  #
  # @param word [String] the word to strip affixes from
  # @param options [Hash] options for the algorithm
  # @option options [Hash] :states The states and valid transitions
  # @option options [Hash] :suffixes The suffixes with their rules
  # @return [Array] all possible stem versions
  def regex_suffix_removal(word, options = {})
    states   = options[:states]   || {}
    suffixes = options[:suffixes] || {}

    return [word] if states.nil?   || states.empty?
    return [word] if suffixes.nil? || suffixes.empty?

    stems    = []
    # Init first state pending transitions
    pendings = states[0][:transitions].map do |transition|
                 {
                   suffix: transition[:suffix],
                   to_state: transition[:state],
                   from_state: 0,
                   word: word
                 }
               end

    while !pendings.empty? do
      info = pendings.pop
      word = info[:word]
      suffix = suffixes[info[:suffix]]
      regex  = suffix[:regex]

      if word.match(/{regex}$/)
        new_word = stem_for(word, suffix)
      end
    end

    return [word] if pendings.empty?
  end

  # Given a suffix it stems a word according to Turkish orthographic rules
  #
  # @param word [String] the word to stem
  # @param suffix [Hash] a suffix record
  # @return [Hash] the partial stem
  def partial_stem(word, suffix)
    stem = (suffix[:check_harmony] && has_vowel_harmony?(word)) ||
           !suffix[:check_harmony]
    suffix_applied = suffix[:regex]

    new_word = if stem
                 word.gsub(/#{suffix_applied}$/, '')
               else
                 suffix_applied = nil
                 word
               end
    if suffix[:extra_y_consonant] && "yY".include?(new_word.chars.last)
      if "yY".include?(new_word.chars.last) && valid_last_y_consonant(word)
      end
    end

    { stem: stem, word: new_word, suffix_applied: suffix_applied }
  end
end
