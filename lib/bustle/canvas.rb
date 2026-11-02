# frozen_string_literal: true

require "adwaita"

require_relative "diagram"
require_relative "regions"

module Bustle
  # The sequence diagram itself: a drawing area in a scrolled window, with a
  # selected message and keyboard navigation between messages.
  #
  # Ported from upstream's Bustle/UI/Canvas.hs and the diagramLayout widget in
  # data/bustle.ui. Upstream draws into a GtkLayout and translates the Cairo
  # context by the scroll offsets by hand; GTK4 has no GtkLayout, so the port
  # sizes a GtkDrawingArea to the diagram and lets the scrolled window do the
  # scrolling — the draw function then works in diagram coordinates directly.
  # The visible rectangle is still computed from the adjustments, because
  # drawing only the shapes that intersect it is what keeps a long log
  # responsive.
  #
  # GTK4 also dropped partial invalidation, so where upstream invalidates the
  # two stripes whose selection changed, this redraws the whole visible area.
  class Canvas
    SCROLL_PADDING_DIVISOR = 2
    PRIMARY_BUTTON = 1

    def initialize(show_bounds: false, on_selection_changed: nil)
      @show_bounds = show_bounds
      @on_selection_changed = on_selection_changed
      @shapes = []
      @width = 0.0
      @selection = Regions::RegionSelection.build([])
    end

    def build
      scroller.tap do |sw|
        sw.child = drawing_area

        drawing_area.tap do |area|
          area.set_draw_func { |_widget, context, _width, _height| draw(context) }
          area.add_controller(click_gesture)
          area.add_controller(key_controller)
        end

        click_gesture.signal_connect("pressed") do |_gesture, _n_press, _x, y|
          drawing_area.grab_focus
          update_selection { |selection| selection.update(y) }
        end

        key_controller.signal_connect("key-pressed") { |_controller, keyval, _code, state| on_key(keyval, state) }
      end
    end

    attr_reader :shapes

    # Replaces the diagram. `centre_offset` and `window_width` are upstream's
    # way of scrolling the fixed timestamp-and-member column into view: the
    # renderer knows where it ended up, the window knows how wide it is, and
    # between them the column lands roughly in the middle.
    def set_shapes(shapes, regions, centre_offset, window_width)
      @shapes = shapes
      @width, height = Diagram.diagram_dimensions(shapes)
      drawing_area.set_size_request(@width.ceil, height.ceil)
      update_selection { |selection| reselect(selection, regions) }
      drawing_area.queue_draw
      horizontal_adjustment.value = centre_offset - ((window_width - Diagram::TIMESTAMP_AND_MEMBER_WIDTH) / 2)
    end

    def focus = drawing_area.grab_focus

    def scroll_to_bottom
      vertical_adjustment.then do |adjustment|
        adjustment.value = [0, adjustment.upper - adjustment.page_size].max
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.hexpand = true
        sw.vexpand = true
      end
    end

    def drawing_area
      @drawing_area ||= Gtk::DrawingArea.new.tap do |area|
        area.focusable = true
      end
    end

    def click_gesture
      @click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
        # Left button only, as upstream's buttonPressEvent handler checks for.
        gesture.button = PRIMARY_BUTTON
      end
    end

    def key_controller = @key_controller ||= Gtk::EventControllerKey.new

    private

      # One row per arrow key, one page per space — and the horizontal keys
      # scroll rather than move the selection, because the diagram is wider
      # than it is navigable.
      def on_key(keyval, state)
        if state.to_i.zero?
          navigate(keyval)
        else
          false
        end
      end

      def navigate(keyval)
        case keyval
        when Gdk::Keyval::KEY_Up then select { |selection| selection.up }
        when Gdk::Keyval::KEY_Down then select { |selection| selection.down }
        when Gdk::Keyval::KEY_Home then select { |selection| selection.first }
        when Gdk::Keyval::KEY_End then select { |selection| selection.last }
        when Gdk::Keyval::KEY_Left then step(horizontal_adjustment, -1)
        when Gdk::Keyval::KEY_Right then step(horizontal_adjustment, 1)
        when Gdk::Keyval::KEY_space then page(vertical_adjustment)
        else false
        end
      end

      def select(&move)
        update_selection(&move)
        true
      end

      def step(adjustment, direction)
        advance(adjustment, direction * adjustment.step_increment)
      end

      def page(adjustment)
        advance(adjustment, adjustment.page_increment)
      end

      # Never scrolls past the top of the last page, which is what upstream's
      # incdec helper is for.
      def advance(adjustment, distance)
        limit = adjustment.upper - adjustment.page_size
        adjustment.value = [adjustment.value + distance, limit].min
        true
      end

      def horizontal_adjustment = scroller.hadjustment

      def vertical_adjustment = scroller.vadjustment

      # Rebuilds the selection over a new set of regions, keeping the selected
      # message selected if it is still in the diagram.
      def reselect(selection, regions)
        Regions::RegionSelection.build(regions).then do |fresh|
          if selection.current
            fresh.select(selection.current.value)
          else
            fresh
          end
        end
      end

      def update_selection(&change)
        previous = @selection.current
        @selection = change.call(@selection)
        unless @selection.current == previous
          drawing_area.queue_draw
          clamp_around_selection
          @on_selection_changed&.call(@selection.current&.value)
        end
      end

      # Brings the selected message into view with half a row's worth of
      # padding either side, so the selection is never flush against an edge.
      def clamp_around_selection
        @selection.current&.stripe&.then do |stripe|
          padding = (stripe.bottom - stripe.top) / SCROLL_PADDING_DIVISOR
          vertical_adjustment.clamp_page(stripe.top - padding, stripe.bottom + padding)
        end
      end

      def draw(context)
        Diagram.draw_region(
          context,
          visible_rectangle,
          drawn_shapes,
          show_bounds: @show_bounds,
        )
      end

      # The highlight behind the selected message is a shape like any other,
      # drawn first so everything else lands on top of it.
      def drawn_shapes
        @selection.current.then do |region|
          if region
            [Diagram::Highlight.new(region: [0, region.stripe.top, @width, region.stripe.bottom])] + @shapes
          else
            @shapes
          end
        end
      end

      def visible_rectangle
        [
          horizontal_adjustment.value,
          vertical_adjustment.value,
          horizontal_adjustment.value + horizontal_adjustment.page_size,
          vertical_adjustment.value + vertical_adjustment.page_size,
        ]
      end
  end
end
