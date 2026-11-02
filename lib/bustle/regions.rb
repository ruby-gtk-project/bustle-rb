# frozen_string_literal: true

module Bustle
  # The canvas's selection model: which horizontal stripe of the diagram is
  # selected, and how clicks and arrow keys move that selection.
  #
  # Ported from upstream's Bustle/Regions.hs. The model is a zipper: the
  # regions before the selection (nearest first, so `before` is reversed), the
  # selected region if any, and the regions after it. A selection may be
  # absent while `before` and `after` are both non-empty, which is how a click
  # in the gap between two messages is remembered — `last_click` then decides
  # which direction the next search runs in.
  #
  # Every operation returns a new RegionSelection; the canvas holds the current
  # one and redraws the stripes that changed.
  module Regions
    # A horizontal band of the diagram, in canvas coordinates.
    Stripe = Data.define(:top, :bottom) do
      def midpoint = (top + bottom) / 2

      def hits?(y) = y >= top && y <= bottom

      def translate(y) = Stripe.new(top: top + y, bottom: bottom + y)

      def <=>(other) = [top, bottom] <=> [other.top, other.bottom]

      include Comparable
    end

    # A stripe and the thing it stands for (for the canvas, a message).
    Region = Data.define(:stripe, :value) do
      def translate(y) = Region.new(stripe: stripe.translate(y), value:)
    end

    class << self
      def translate_regions(y, regions) = regions.map { |region| region.translate(y) }

      # True when no two stripes overlap, assuming they are already sorted.
      def non_overlapping?(stripes)
        stripes.each_cons(2).all? { |first, second| first.bottom <= second.top }
      end
    end

    # The zipper itself.
    class RegionSelection
      attr_reader :before, :last_click, :current, :after

      class << self
        # Upstream treats unsorted or overlapping regions as a programming
        # error, and so does the port: the renderer emits regions in order, so
        # anything else means the diagram is wrong.
        def build(regions)
          stripes = regions.map(&:stripe)
          unless stripes.sort == stripes
            raise ArgumentError, "unsorted regions"
          end
          unless Regions.non_overlapping?(stripes)
            raise ArgumentError, "overlapping regions"
          end

          new(before: [], last_click: 0, current: nil, after: regions)
        end
      end

      def initialize(before:, last_click:, current:, after:)
        @before = before
        @last_click = last_click
        @current = current
        @after = after
      end

      def flatten = before.reverse + [current].compact + after

      def with(before: @before, last_click: @last_click, current: @current, after: @after)
        self.class.new(before:, last_click:, current:, after:)
      end

      # Adds freshly-rendered regions below the existing ones, which is how a
      # live recording extends the diagram without losing the selection.
      def append(regions)
        case regions
        when []
          self
        else
          append_after(RegionSelection.build(regions), regions.first)
        end
      end

      # Moves the selection to whatever region contains `y`, remembering the
      # click even when it landed between two regions.
      def update(y)
        searched(y).with(last_click: y)
      end

      def up
        case before
        when []
          self
        else
          with(
            before:     before.drop(1),
            last_click: before.first.stripe.midpoint,
            current:    before.first,
            after:      [current].compact + after,
          )
        end
      end

      def down = invert.up.invert

      def first
        case flatten
        when []
          self
        else
          self.class.new(
            before:     [],
            last_click: flatten.first.stripe.midpoint,
            current:    flatten.first,
            after:      flatten.drop(1),
          )
        end
      end

      def last = invert.first.invert

      # Re-selects a value in a freshly-rebuilt selection, so re-rendering the
      # diagram (after a filter change, say) keeps the selected message.
      def select(value)
        if current&.value == value
          self
        else
          select_from_before(value) || select_from_after(value) || self
        end
      end

      def invert = with(before: after, after: before)

      private

        def append_after(fresh, new_first)
          last_region = last.current
          if last_region.nil?
            fresh
          elsif last_region.stripe < new_first.stripe &&
              Regions.non_overlapping?([last_region.stripe, new_first.stripe])
            with(after: after + fresh.after)
          else
            raise ArgumentError, "new regions overlap old regions"
          end
        end

        def searched(y)
          if current&.stripe&.hits?(y)
            self
          elsif current
            search(y, before, [current] + after)
          else
            search(y, before, after)
          end
        end

        # Searching upwards walks the reversed `before` list and pushes what it
        # passes onto `after`; searching downwards does the mirror image.
        def search(y, befores, afters)
          if y <= last_click
            afters_out, found, befores_out = scan(y, afters, befores) { |stripe| y <= stripe.bottom }
            with(before: befores_out, current: found, after: afters_out)
          else
            befores_out, found, afters_out = scan(y, befores, afters) { |stripe| y >= stripe.top }
            with(before: befores_out, current: found, after: afters_out)
          end
        end

        # Walks `afters` looking for the region containing `y`, moving what it
        # passes onto `befores` for as long as the block says it is worth
        # continuing.
        def scan(y, befores, afters, &worth_continuing)
          passed = befores
          remaining = afters
          found = nil
          while found.nil? && !remaining.empty?
            candidate = remaining.first
            if candidate.stripe.hits?(y)
              found = candidate
              remaining = remaining.drop(1)
            elsif worth_continuing.call(candidate.stripe)
              passed = [candidate] + passed
              remaining = remaining.drop(1)
            else
              break
            end
          end
          [passed, found, remaining]
        end

        def select_from_before(value)
          before.index { |region| region.value == value }&.then do |index|
            with(
              before:     before.drop(index + 1),
              last_click: before[index].stripe.midpoint,
              current:    before[index],
              after:      before.take(index).reverse + after,
            )
          end
        end

        def select_from_after(value)
          after.index { |region| region.value == value }&.then do |index|
            with(
              before:     before + after.take(index).reverse,
              last_click: after[index].stripe.midpoint,
              current:    after[index],
              after:      after.drop(index + 1),
            )
          end
        end
    end
  end
end
