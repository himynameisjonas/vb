# frozen_string_literal: true

class VB::NamesTest < TLDR
  def test_generates_hyphenated_name
    name = VB::Names.generate
    assert_match(/\A[a-z]+-[a-z]+\z/, name)
  end

  def test_seeded_generation_is_deterministic
    name1 = VB::Names.generate(seed: 42)
    name2 = VB::Names.generate(seed: 42)
    assert_equal name1, name2
  end

  def test_different_seeds_produce_variety
    names = (1..20).map { |i| VB::Names.generate(seed: i) }
    assert names.uniq.length > 1
  end
end
