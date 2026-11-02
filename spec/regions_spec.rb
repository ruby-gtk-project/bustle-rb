# frozen_string_literal: true

require "bustle/regions"

# Ported from upstream's Test/Regions.hs, the `test-regions` suite: fourteen
# QuickCheck properties over Bustle.Regions.
#
# They are properties, not examples, so each one runs over a hundred generated
# region lists rather than one hand-written list — several of these (clicking
# any stripe, clicking every stripe in a shuffled order, the last-click
# invariant) are satisfied by accident by any single example. The generator is
# upstream's: a sorted list of tops, one stripe per adjacent pair reaching some
# fraction of the way to the next top, with that fraction pinned at 1.0 one
# time in eight so stripes sometimes touch exactly.
#
# One deliberate difference. Upstream draws its tops from `arbitrary ::
# Double`, which is signed, and `regionSelectionUpdate` compares the click
# against `rsLastClick`, which starts at 0 — so a region list entirely above
# the origin makes prop_UpdateToFirst search upwards through an empty `before`
# and find nothing. Diagram coordinates are never negative (the canvas's
# y axis starts at 0), so the generator here stays non-negative and the
# properties mean what they say.
# Upstream's Arbitrary instances, kept out of the example group so the
# generator is a thing with a name rather than a constant hidden in a block.
module RegionsProperties
  TRIALS = 100
  SEED = 20_181_115
  MAX_TOP = 1000.0
  DENSE_IN = 8

  # Upstream's Arbitrary NonOverlappingStripes and ValidRegions.
  module Generator
    class << self
      def valid_regions(random)
        stripes(random).each_with_index.map do |stripe, index|
          Bustle::Regions::Region.new(stripe: stripe, value: index)
        end
      end

      # The bottom is clamped to the next top: with a ratio just under 1.0,
      # `top + (height * ratio)` can round to a hair above `next_top` and
      # produce an overlap the generator did not intend.
      def stripes(random)
        tops(random).each_cons(2).map do |top, next_top|
          Bustle::Regions::Stripe.new(
            top:    top,
            bottom: [top + ((next_top - top) * ratio(random)), next_top].min,
          )
        end
      end

      # At least two tops, so there is at least one stripe.
      def tops(random)
        Array.new(3 + random.rand(9)) { random.rand(MAX_TOP) }.sort
      end

      def ratio(random)
        if random.rand(DENSE_IN).zero?
          1.0
        else
          random.rand
        end
      end

      # Upstream's `shuffled`.
      def shuffle(items, random) = items.shuffle(random: random)

      # Upstream's randomMutations: any sequence of the five operations that
      # move a selection, with arbitrary clicks among them.
      def mutations(random)
        Array.new(random.rand(10)) { mutation(random) }
      end

      def mutation(random)
        [
          ->(selection) { selection.up },
          ->(selection) { selection.down },
          ->(selection) { selection.first },
          ->(selection) { selection.last },
          ->(selection) { selection.update(random.rand(-MAX_TOP..MAX_TOP)) },
        ].sample(random: random)
      end
    end
  end

  # Each property runs over the same hundred generated region lists, from a
  # fixed seed so a failure can be reproduced.
  def each_case
    Random.new(SEED).then do |random|
      TRIALS.times { yield(Generator.valid_regions(random), random) }
    end
  end

  def selection_over(regions) = Bustle::Regions::RegionSelection.build(regions)
end

RSpec.describe Bustle::Regions do
  include RegionsProperties

  # 1. prop_NonOverlapping_generator_works
  it "generates stripes that do not overlap" do
    each_case do |regions, _random|
      expect(Bustle::Regions.non_overlapping?(regions.map(&:stripe))).to be(true)
    end
  end

  # 2. prop_InitiallyUnselected
  it "selects nothing to begin with" do
    each_case do |regions, _random|
      expect(selection_over(regions).current).to be_nil
    end
  end

  # 3. prop_UpDoesNothing
  it "selects nothing when moving up from an unselected selection" do
    each_case do |regions, _random|
      expect(selection_over(regions).up.current).to be_nil
    end
  end

  # 4. prop_DownDoesNothing
  it "stays on the last region when moving down from it" do
    each_case do |regions, _random|
      expect(selection_over(regions).last.down.current).to eq(regions.last)
    end
  end

  # 5. prop_DownWorks
  it "selects the first region when moving down from an unselected selection" do
    each_case do |regions, _random|
      expect(selection_over(regions).down.current).to eq(regions.first)
    end
  end

  # 6. prop_UpdateToFirst
  it "selects the first region when clicked inside it, with nothing before it" do
    each_case do |regions, _random|
      selection_over(regions).update(regions.first.stripe.midpoint).then do |updated|
        expect(updated.current).to eq(regions.first)
        expect(updated.before).to be_empty
      end
    end
  end

  # 7. prop_SelectFirst
  it "selects the first region on First" do
    each_case do |regions, _random|
      expect(selection_over(regions).first.current).to eq(regions.first)
    end
  end

  # 8. prop_SelectLast
  it "selects the last region on Last" do
    each_case do |regions, _random|
      expect(selection_over(regions).last.current).to eq(regions.last)
    end
  end

  # 9. prop_UpdateToAny
  it "selects exactly the region a click lands in, for every region" do
    each_case do |regions, _random|
      regions.each do |region|
        expect(selection_over(regions).update(region.stripe.midpoint).current).to eq(region)
      end
    end
  end

  # 10. prop_UpdateToAll
  it "keeps up with clicks on every region in a shuffled order" do
    each_case do |regions, random|
      RegionsProperties::Generator.shuffle(regions, random).reduce(selection_over(regions)) do |selection, region|
        selection.update(region.stripe.midpoint).tap do |updated|
          expect(updated.current).to eq(region)
        end
      end
    end
  end

  # 11. prop_ClickAlwaysInSelection — the invariant Canvas#clamp_around_selection
  # relies on: whenever something is selected, the last click is inside it.
  it "keeps the last click inside the selected stripe after any sequence of moves" do
    each_case do |regions, random|
      RegionsProperties::Generator.mutations(random).reduce(selection_over(regions)) do |selection, mutation|
        mutation.call(selection)
      end.then do |mutated|
        mutated.current&.stripe&.then do |stripe|
          expect(stripe.top).to be <= mutated.last_click
          expect(mutated.last_click).to be <= stripe.bottom
        end
      end
    end
  end

  # 12. prop_SelectWorks
  it "selects the region holding a given value, wherever the cursor is" do
    each_case do |regions, random|
      regions.sample(random: random).then do |region|
        expect(selection_over(regions).select(region.value).current).to eq(region)
      end
    end
  end

  # 13. prop_Append — what lets a live recording extend the diagram without
  # losing the selection.
  it "appends regions to make the same selection as building the whole list" do
    each_case do |regions, random|
      random.rand(regions.length).then do |split|
        expect(selection_over(regions.take(split)).append(regions.drop(split)))
          .to eq(selection_over(regions))
      end
    end
  end

  # 14. prop_FlattenThenNewIsIdempotent
  it "rebuilds an identical selection from its own flattened regions" do
    each_case do |regions, _random|
      selection_over(regions).then do |selection|
        expect(selection_over(selection.flatten)).to eq(selection)
      end
    end
  end
end
