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

  describe ".regex_suffix_removal" do
    context "when states are empty" do
      it "returns the word" do
        expect(
          described_class.
            regex_suffix_removal("kapıdır", suffixes: :test)).to eq(["kapıdır"])
      end
    end

    context "when suffixes are empty" do
      it "return the word" do
        expect(
          described_class.
            regex_suffix_removal("kapıdır", states: :test)).to eq(["kapıdır"])
      end
    end

    context "when we pass suffixes and states" do
    end
  end

  describe ".partial_stem" do
    let(:suffix) do
      {
        name: "-dir",
        regex: "dir",
        extra_y_consonant: false,
        check_harmony: true
      }
    end

    context "when word matches suffix" do
      it "partially stems a word" do
        expect(
          described_class.
            partial_stem("Türkiyedir", suffix)).
        to eq({ stem: true, word: "Türkiye", suffix_applied: "dir" })
      end

      context "when suffix has harmony check on" do
        before do
          suffix[:regex] = "dan"
        end

        it "does not stem a word that does not obey harmony rules" do
          expect(
            described_class.
              partial_stem("kürdan", suffix)).
          to eq({ stem: false, word: "kürdan", suffix_applied: nil })
        end
      end

      context "when suffix has (y) as optional letter" do
        before do
          suffix[:extra_y_consonant] = true
          suffix[:regex] = "um"
        end

        context "and new word has valid last 'y' symbol" do
          it "stems correctly and increases the suffix" do
            expect(
              described_class)
          end
        end
      end
    end
  end
end