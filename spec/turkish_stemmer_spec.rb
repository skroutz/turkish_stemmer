# coding: utf-8
require "spec_helper"
require "pry"

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

  describe ".valid_last_y_consonant" do
    context "when a word ends with 'y'" do
      context "and the preceding letter is a vowel" do
        it "has valid last y consonant" do
          expect(described_class).to be_valid_last_y_consonant("litey")
        end
      end

      context "and the preceding letter is a consonant" do
        it "does not have a valid last y consonant" do
          expect(described_class).not_to be_valid_last_y_consonant("lity")
        end
      end
    end
  end

  describe ".affix_morphological_stripper", :focus do
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

    context "when we pass suffixes and simple states" do
      it "strips suffixes correctly" do
        expect(
          described_class.
            affix_morphological_stripper("çocuğuymuşum",
                                 states: described_class::NOMINAL_VERB_STATES,
                                 suffixes: described_class::NOMINAL_VERB_SUFFIXES)).
        to eq %w{ çocuğu }
      end
    end
  end

  describe ".mark_stem" do
    let(:suffix) do
      {
        name: "-dir",
        regex: "dir",
        extra_y_consonant: false,
        check_harmony: true
      }
    end

    context "when suffix has harmony check on" do
      before do
        suffix[:regex] = "dan"
      end

      it "does not stem a word that does not obey harmony rules" do
        expect(
          described_class.
            mark_stem("kürdan", suffix)).
        to eq({ stem: false, word: "kürdan", suffix_applied: nil })
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
          suffix[:extra_y_consonant] = true
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
        to eq [:suffix, :to_state, :from_state, :word, :rollback]
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
end