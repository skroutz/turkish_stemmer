# coding: utf-8
require "spec_helper"
require "pry"
require "csv"

describe TurkishStemmer do

  describe ".count_syllables" do
    it "counts syllables correctly" do
      expect(described_class.count_syllables("erikler")).to eq 3
      expect(described_class.count_syllables("çocuklarımmış")).to eq 5
    end
  end

  describe ".vowels" do
    it "returns all vowels of a word" do
      expect(described_class.vowels("kötüymüş")).to eq(%w(ö ü ü))
    end
  end

  describe ".has_roundness?" do
    context "when vowel is empty" do
      it "has roundness" do
        expect(described_class).to have_roundness(nil, "a")
      end
    end

    context "when candidate is empty" do
      it "has roundness" do
        expect(described_class).to have_roundness("a", nil)
      end
    end

    context "when an unrounded vowel is passed" do
      let(:vowel) { described_class::UNROUNDED_VOWELS.chars.sample }

      context "and candidate is an unrounded vowel too" do
        let(:candidate) { described_class::UNROUNDED_VOWELS.chars.sample }

        it "has roundness" do
          expect(described_class).to have_roundness(vowel, candidate)
        end
      end

      context "and candidate is not an unrounded vowel" do
        let(:candidate) { described_class::ROUNDED_VOWELS.chars.sample }

        it "does not have roundness" do
          expect(described_class).not_to have_roundness(vowel, candidate)
        end
      end
    end

    context "when a rounded vowel is passed" do
      let(:vowel) { described_class::ROUNDED_VOWELS.chars.sample }

      context "and one of 'a', 'e', 'u' or 'ü' is a candidate" do
        let(:candidate) { described_class::FOLLOWING_ROUNDED_VOWELS.chars.sample }

        it "has roundness" do
          expect(described_class).to have_roundness(vowel, candidate)
        end
      end

      context "and candidate is 'o'" do
        let(:candidate) { 'o' }

        it "does not have roundness" do
          expect(described_class).not_to have_roundness(vowel, candidate)
        end
      end
    end
  end

  describe ".has_frontness?" do
    context "when vowel is empty" do
      it "has frontness" do
        expect(described_class).to have_frontness(nil, "a")
      end
    end

    context "when candidate is empty" do
      it "has frontness" do
        expect(described_class).to have_frontness("a", nil)
      end
    end

    context "when a front vowel is passed" do
      let(:vowel) { described_class::FRONT_VOWELS.chars.sample }

      context "and candidate is a front vowel" do
        let(:candidate) { described_class::FRONT_VOWELS.chars.sample }

        it "has frontness" do
          expect(described_class).to have_frontness(vowel, candidate)
        end
      end

      context "and candidate is a back vowel" do
        let(:candidate) { described_class::BACK_VOWELS.chars.sample }

        it "does not have frontness" do
          expect(described_class).not_to have_frontness(vowel, candidate)
        end
      end
    end

    context "when a back vowel is passed" do
      let(:vowel) { described_class::BACK_VOWELS.chars.sample }

      context "and candidate is a front vowel" do
        let(:candidate) { described_class::FRONT_VOWELS.chars.sample }

        it "does not have frontness" do
          expect(described_class).not_to have_frontness(vowel, candidate)
        end
      end

      context "and candidate is a back vowel" do
        let(:candidate) { described_class::BACK_VOWELS.chars.sample }

        it "has frontness" do
          expect(described_class).to have_frontness(vowel, candidate)
        end
      end
    end
  end

  describe ".has_vowel_harmony?" do
    it "has vowel harmony for valid Turkish words" do
      expect(described_class).to have_vowel_harmony("Türkiyedir")
      expect(described_class).to have_vowel_harmony("kapıdır")
      expect(described_class).to have_vowel_harmony("gündür")
      expect(described_class).to have_vowel_harmony("paltodur")
    end

    it "does not have vowel harmony for loanwords" do
      expect(described_class).not_to have_vowel_harmony("kürdan")
    end

    it "does not have vowel harmony for exceptions" do
      expect(described_class).not_to have_vowel_harmony("anne")
      expect(described_class).not_to have_vowel_harmony("kardeş")
    end
  end

  describe ".affix_morphological_stripper" do
    context "when states are empty" do
      it "returns the word" do
        expect(
          described_class.
            affix_morphological_stripper("kapıdır", suffixes: :test)).
        to eq(["kapıdır"])
      end
    end

    context "when suffixes are empty" do
      it "return the word" do
        expect(
          described_class.
            affix_morphological_stripper("kapıdır", states: :test)).
        to eq(["kapıdır"])
      end
    end

    context "when there exist states and suffixes"  do
      let(:states) {
        described_class.
          load_states_or_suffixes("spec/fixtures/simple_state.yml")
      }

      let(:suffixes) {
        described_class.
          load_states_or_suffixes("spec/fixtures/simple_suffix.yml")
      }

      it "generates pendings for the initial state" do
        described_class.should_receive(:generate_pendings).with(:a,
          "word", states).and_call_original

        described_class.affix_morphological_stripper("word",
          states: states, suffixes: suffixes)
      end
    end

    context "when a transition is valid"  do
      let(:states) {
        described_class.
          load_states_or_suffixes("spec/fixtures/simple_state.yml")
      }

      let(:suffixes) {
        described_class.
          load_states_or_suffixes("spec/fixtures/simple_suffix.yml")
      }

      context "and the transit state is a final state" do
        it "removes similar pending transitions" do
          described_class.should_receive(:mark_stem).with(
            "guzelim", suffixes[:s1]).and_call_original

          described_class.affix_morphological_stripper(
            "guzelim", states: states, suffixes: suffixes)
        end

        context "with no other transitions" do
          it "stems the word" do
            expect(
              described_class.
                affix_morphological_stripper("guzelim",
                  states: states, suffixes: suffixes)).
            to eq ["guzel"]
          end
        end

        context "with other transitions"  do
          let(:states) {
            described_class.load_states_or_suffixes("spec/fixtures/simple_state_02.yml")
          }

          it "adds more pendings to check" do
            described_class.should_receive(:mark_stem).with("guzelim",
              suffixes[:s1]).and_call_original

            described_class.should_receive(:mark_stem).with("guzel",
              suffixes[:s1]).and_call_original

            described_class.affix_morphological_stripper("guzelim",
              states: states, suffixes: suffixes)
          end
        end
      end
    end

    context "when one suffix matches correctly with a given word" do
      let(:unreachable_suffix) {
        described_class::NOMINAL_VERB_SUFFIXES[:s3]
      }

      it "does not compare other suffixes in the same transition" do
        described_class.
          should_receive(:mark_stem).
          with(anything, anything).
          exactly(17).times.
          and_call_original

        puts described_class.
          affix_morphological_stripper("taksicisiniz",
            states: described_class::NOMINAL_VERB_STATES,
            suffixes: described_class::NOMINAL_VERB_SUFFIXES)
      end
    end
  end

  describe ".stem"  do
    context "when input is single syllable" do
      it "returns the input as is" do
        expect(described_class.stem("ev")).to eq "ev"
      end
    end

    context "when input has zero syllables - one consonant" do
      it "returns the input as is" do
        expect(described_class.stem("p")).to eq "p"
      end
    end
  end

  describe ".last_consonant!"  do
    context "when last consonant is among 'b', 'c', 'd' or 'ğ'" do
      it "is replaced by 'p', 'ç', 't' or 'k'" do
        expect(described_class.last_consonant!('kebab')).to eq('kebap')
        expect(described_class.last_consonant!('kebac')).to eq('kebaç')
        expect(described_class.last_consonant!('kebad')).to eq('kebat')
        expect(described_class.last_consonant!('kebağ')).to eq('kebak')
      end
    end

    context "when word belongs to protected words" do
      it "does not replace last consonant" do
        expect(described_class.last_consonant!('ad')).to eq('ad')
      end
    end
  end

  describe ".mark_stem" do
    let(:suffix) do
      {
        name: "-dir",
        regex: "dir",
        optional_letter: false,
        check_harmony: true
      }
    end

    context "when suffix has harmony check on" do
      before do
        suffix[:regex] = "dan"
      end

      context "and word does not obey harmony rules" do
        it "does not stem a word that does not obey harmony rules" do
          expect(described_class.mark_stem("kürdan", suffix)).to eq(
            { stem: false, word: "kürdan", suffix_applied: nil })
        end

        context "and word belongs to exceptions" do
          before do
            suffix[:regex] = "ler"
          end
          it "stems the word" do
            expect(described_class.mark_stem("saatler", suffix)).to eq(
              { stem: true, word: "saat", suffix_applied: "ler" })
          end
        end
      end

    end

    context "when suffix has harmony check off" do
      before do
        suffix[:regex] = "dan"
        suffix[:check_harmony] = false
      end

      it "stems a word that does not obey harmony rules" do
        expect(
          described_class.
            mark_stem("kürdan", suffix)).
        to eq({ stem: true, word: "kür", suffix_applied: "dan" })
      end
    end

    context "when word matches suffix" do
      it "partially stems a word" do
        expect(
          described_class.
            mark_stem("Türkiyedir", suffix)).
        to eq({ stem: true, word: "Türkiye", suffix_applied: "dir" })
      end


      context "when suffix has (y) as optional letter" do
        before do
          suffix[:optional_letter] = "y|y"
          suffix[:regex] = "um"
        end

        context "and new word has valid last 'y' symbol" do
          it "stems correctly and increases the suffix" do
            expect(
              described_class.
                mark_stem("loyum", suffix)).
            to eq({ stem: true, word: "lo", suffix_applied: "yum" })
          end
        end

        context "and new word does not have valid last 'y' symbol" do
          it "does not stem the word" do
            expect(
              described_class.
                mark_stem("lotyum", suffix)).
            to eq({ stem: false, word: "lotyum", suffix_applied: nil })
          end
        end
      end
    end
  end

  describe ".generate_pendings" do
    let(:states) { described_class::NOMINAL_VERB_STATES }

    it "raises an error if state does not exist" do
      expect {
        described_class.
          generate_pendings(1, "test", states)
      }.to raise_error(ArgumentError, "State #{1} does not exist")
    end

    context "when state key does not have transitions" do
      it "returns an empty array" do
        expect(
          described_class.
            # :f state does not have transitions
            generate_pendings(:f, "test", states)).
        to eq []
      end
    end

    context "when state key has transitions" do
      it "returns an array of hashes for each transition" do
        expect(
          described_class.
            generate_pendings(:a, "test", states).first.keys).
        to eq [:suffix, :to_state, :from_state, :word, :rollback, :mark]
      end

      it "sets :from_state key to current key state" do
        expect(
          described_class.
            generate_pendings(:a, "test", states).first[:from_state]).
        to eq :a
      end

      context "when state is not final" do
        it "sets :rollback to current word" do
          expect(
            described_class.
              # :a state is not final
              generate_pendings(:a, "test", states).first[:rollback]).
          to eq nil
        end

        context "and rollback is passed" do
          it "sets :rollback to passed option" do
            expect(
              described_class.
                generate_pendings(:a, "test", states, rollback: "custom").
                  first[:rollback]).
            to eq "custom"
          end
        end
      end

      context "when state is final" do
        it "sets :rollback to current word" do
          expect(
            described_class.
              # :b state is final
              generate_pendings(:b, "test", states).first[:rollback]).
          to eq "test"
        end

        context "and rollback is passed" do
          it "sets :rollback to passed option" do
            expect(
              described_class.
                generate_pendings(:a, "test", states, rollback: "custom").
                  first[:rollback]).
            to eq "custom"
          end
        end
      end
    end
  end

  describe ".valid_optional_letter?" do
    context "when last letter of the word is not equal to candidate" do
      it "responds with [true,nil] - indicating that there was not match" do
        expect(
          described_class.valid_optional_letter?("test", "r")).
        to eq([true, nil])
      end
    end

    context "when there is a vowel match" do
      context "and the previous char is a vowel" do
        it "responds with false" do
          expect(
            described_class.
              valid_optional_letter?("takcicii", "i")).
          to eq([false, "i"])
        end
      end

      context "and the previous char is a consonant" do
        it "responds with true" do
          expect(
            described_class.
              valid_optional_letter?("okula", "a")).
          to eq([true, "a"])
        end
      end
    end

    context "when there is a consonant match" do
      context "and the previous char is a vowel" do
        it "responds with true" do
          expect(
            described_class.
              valid_optional_letter?("litiy", "y")).
          to eq([true, "y"])
        end
      end

      context "and the previous char is a consonant" do
        it "responds with true" do
          expect(
            described_class.
              valid_optional_letter?("lity", "y")).
          to eq([false, "y"])
        end
      end
    end
  end

  describe ".stem_post_process"  do
    context "when input stream has words with last consonant replacements" do
      it "replaces last consonant" do
        expect(described_class.stem_post_process(["kebab"], "word")).to eq("kebap")
      end
    end

    it "flattens and uniq results" do
      expect(described_class.stem_post_process(["kitap",["kitap"]], "word")).to eq("kitap")
    end

    it "removes no syllables words" do
      expect(described_class.stem_post_process(["kitap", "k"], "word")).to eq("kitap")
    end

    context "when multiple stem candidates exist" do
      it "returns the shortest" do
        expect(described_class.stem_post_process(["kitap", "kita", "kit"], "word")).to eq "kit"
      end
    end
  end

  describe ".proceed_to_stem?"  do
    context "when word has 1 or less syllables" do
      it "returns false" do
        expect(described_class.proceed_to_stem?("kit")).not_to be
      end
    end

    context "when word does not have harmony" do
      it "returns false" do
        expect(described_class.proceed_to_stem?("taki")).not_to be
      end

      context "and word is an exception" do
        it "returns true" do
          expect(described_class.proceed_to_stem?("saatler")).to be
        end
      end
    end

    context "when word is nil" do
      it "returns false" do
        expect(described_class.proceed_to_stem?(nil)).not_to be
      end
    end

    context "when word is empty" do
      it "returns false" do
        expect(described_class.proceed_to_stem?("")).not_to be
      end
    end

    context "when word is among protected words" do
      it "returns false" do
        expect(described_class.proceed_to_stem?("soyad")).not_to be
      end
    end
  end

  context "1:1 testing with paper" do
    CSV.read("spec/support/fixtures.csv").each do |row|
      it "stems #{row[0]} correct" do
        expect(described_class.stem(row[0].downcase)).to eq row[1].downcase
      end
    end
  end
end
