# frozen_string_literal: true

module VB
  class Names
    ADJECTIVES = %w[brave calm cool dark fast fierce gentle happy kind light].freeze
    NOUNS = %w[falcon hawk lynx otter wolf badger crane eagle finch gecko].freeze

    def self.generate(seed: nil)
      rng = seed ? Random.new(seed) : Random.new
      "#{ADJECTIVES.sample(random: rng)}-#{NOUNS.sample(random: rng)}"
    end
  end
end
