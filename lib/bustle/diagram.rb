# frozen_string_literal: true

require "gtk4"
require "pango"

require_relative "marquee"

module Bustle
  # The shape algebra the renderer emits and the canvas draws.
  #
  # Ported from upstream's Bustle/Diagram.hs. A diagram is a flat array of
  # shapes in diagram coordinates; nothing here knows about widgets, which is
  # why the same shapes draw onto the canvas and into a PDF surface. Each
  # shape can say where it is (`bounds`), move (`translate`) and draw itself
  # onto a Cairo context, so clipping to the visible area is a filter over the
  # array rather than anything cleverer.
  #
  # The hardcoded widths are upstream's and the renderer depends on them: the
  # timestamp and member columns are fixed, and participants' columns are laid
  # out COLUMN_WIDTH apart to either side.
  module Diagram
    EVENT_HEIGHT = 30.0

    TIMESTAMP_WIDTH = 60.0
    TIMESTAMP_X = TIMESTAMP_WIDTH / 2

    MEMBER_WIDTH = 340.0
    MEMBER_X = TIMESTAMP_WIDTH + (MEMBER_WIDTH / 2)

    TIMESTAMP_AND_MEMBER_WIDTH = TIMESTAMP_WIDTH + MEMBER_WIDTH

    COLUMN_WIDTH = 90.0

    # Method return arcs can go outside the first column. Empirically, 20 is
    # enough to stop the arc (or the duration text) overlapping the object
    # path — upstream's comment, upstream's number.
    FIRST_COLUMN_OFFSET = 20 + (COLUMN_WIDTH / 2)

    PADDING = 6.0
    HEADER_LINE_HEIGHT = 10.0

    ABOVE = :above
    BELOW = :below

    LEFT = :left
    RIGHT = :right

    Colour = Data.define(:red, :green, :blue)

    ERROR_COLOUR = Colour.new(red: 1.0, green: 0.0, blue: 0.0)

    class << self
      def header_height(names) = HEADER_LINE_HEIGHT * names.length

      # Bottom-justifies a row of headers: a participant with three names and
      # one with a single name still have their last line on the same
      # baseline. Returns the row's height and its shapes.
      def headers(columns, y)
        if columns.empty?
          [0.0, []]
        else
          heights = columns.map { |(_x, names)| header_height(names) }
          height = heights.max
          shapes = columns.zip(heights).map do |(x, names), own|
            Header.new(names:, x:, y: y + (height - own))
          end
          [height, shapes]
        end
      end

      def member_label(path, interface, member, is_return, y)
        MemberLabel.new(path:, interface:, member:, is_return:, x: MEMBER_X, y:)
      end

      def timestamp_label(text, y) = TimestampLabel.new(text:, x: TIMESTAMP_X, y:)

      def diagram_dimensions(shapes)
        bounds = diagram_bounds(shapes)
        [bounds[2] - bounds[0], bounds[3] - bounds[1]]
      end

      # Shifts a diagram into positive space, returning the translation it
      # applied along with the moved shapes. The canvas needs the translation
      # to keep its region list in step.
      def top_left_justify(shapes)
        x1, y1, = diagram_bounds(shapes)
        translation = [-x1, -y1]
        [translation, translate_diagram(translation, shapes)]
      end

      def translate_diagram(translation, shapes)
        shapes.map { |shape| shape.translate(translation[0], translation[1]) }
      end

      def diagram_bounds(shapes)
        boxes = shapes.map(&:bounds)
        [
          (boxes.map { |box| box[0] } + [0.0]).min - PADDING,
          (boxes.map { |box| box[1] } + [0.0]).min - PADDING,
          (boxes.map { |box| box[2] } + [0.0]).max + PADDING,
          (boxes.map { |box| box[3] } + [0.0]).max + PADDING,
        ]
      end

      def draw_diagram(context, shapes, show_bounds: false)
        draw_filtered(context, shapes, show_bounds:) { true }
      end

      # Draws only the shapes touching `rect`, which is how the canvas gets
      # away with holding the whole diagram in memory.
      def draw_region(context, rect, shapes, show_bounds: false)
        draw_filtered(context, shapes, show_bounds:) { |shape| intersects?(rect, shape.bounds) }
      end

      def intersects?(one, other)
        !(one[0] > other[2] || one[2] < other[0] || one[1] > other[3] || one[3] < other[1])
      end

      def font
        @font ||= Pango::FontDescription.new("Sans 7")
      end

      # Every piece of text in the diagram comes through here, at the one font
      # size upstream uses, with markup rather than plain text so the member
      # labels can embolden and dim parts of themselves.
      def layout(context, marquee, ellipsize: :none, alignment: :left, width: nil)
        context.create_pango_layout.tap do |text|
          text.markup = marquee.to_markup
          text.font_description = font
          text.ellipsize = ellipsize
          text.alignment = alignment
          if width
            text.width = (width * Pango::SCALE).to_i
          end
        end
      end

      # The pangocairo entry points live on the Cairo context in the Ruby
      # bindings (`Pango::Cairo` is not a namespace they define), so a layout
      # is made by the context that will draw it and shown through the same.
      def show_layout(context, text) = context.show_pango_layout(text)

      def from_centre(x, y, width)
        [x - (width / 2), y - (EVENT_HEIGHT / 2), x + (width / 2), y + (EVENT_HEIGHT / 2)]
      end

      private

        def draw_filtered(context, shapes, show_bounds:, &visible)
          clear_canvas(context)
          shapes.select(&visible).each do |shape|
            if show_bounds
              draw_bounding_box(context, shape)
            end
            shape.draw(context)
          end
        end

        def clear_canvas(context)
          context.save do
            context.set_source_rgb(1, 1, 1)
            context.operator = Cairo::OPERATOR_SOURCE
            context.paint
          end
        end

        # Upstream's --debug flag draws every shape's bounding box in blue;
        # it is the only way to see why two shapes overlap.
        def draw_bounding_box(context, shape)
          context.save do
            x1, y1, x2, y2 = shape.bounds
            context.set_source_rgb(0, 0, 1)
            context.rectangle(
              x1,
              y1,
              x2 - x1,
              y2 - y1,
            )
            context.stroke
          end
        end
    end

    # The names of one participant, stacked above its column.
    Header = Data.define(:names, :x, :y) do
      def bounds
        [x - (COLUMN_WIDTH / 2), y, x + (COLUMN_WIDTH / 2), y + Diagram.header_height(names)]
      end

      def translate(dx, dy) = with(x: x + dx, y: y + dy)

      def draw(context)
        names.each_with_index do |name, index|
          text = Diagram.layout(
            context,
            Marquee.escape(name),
            ellipsize: :end,
            alignment: :center,
            width:     COLUMN_WIDTH,
          )
          context.move_to(x - (COLUMN_WIDTH / 2), y + (index * HEADER_LINE_HEIGHT))
          Diagram.show_layout(context, text)
        end
      end
    end

    # The object path and member of a message, in the fixed left-hand column.
    # A call shows its path in bold; a return shows the call's member in
    # italics, because the return itself has no member of its own.
    MemberLabel = Data.define(
      :path,
      :interface,
      :member,
      :is_return,
      :x,
      :y,
    ) do
      def bounds = Diagram.from_centre(x, y, MEMBER_WIDTH)

      def translate(dx, dy) = with(x: x + dx, y: y + dy)

      def draw(context)
        draw_line(context, path_marquee, y - 10)
        draw_line(context, member_marquee, y)
      end

      private

        def draw_line(context, marquee, line_y)
          text = Diagram.layout(context, marquee, ellipsize: :start, width: MEMBER_WIDTH)
          context.move_to(x - (MEMBER_WIDTH / 2), line_y)
          Diagram.show_layout(context, text)
        end

        def path_marquee
          if is_return
            Marquee.escape(path)
          else
            Marquee.b(Marquee.escape(path))
          end
        end

        def member_marquee
          Marquee.format_member(interface, member).then do |formatted|
            if is_return
              Marquee.i(formatted)
            else
              formatted
            end
          end
        end
    end

    # Milliseconds since the first message in the log.
    TimestampLabel = Data.define(:text, :x, :y) do
      def bounds = Diagram.from_centre(x, y, TIMESTAMP_WIDTH)

      def translate(dx, dy) = with(x: x + dx, y: y + dy)

      def draw(context)
        layout = Diagram.layout(context, Marquee.escape(text), width: TIMESTAMP_WIDTH)
        context.move_to(x - (TIMESTAMP_WIDTH / 2), y - 10)
        Diagram.show_layout(context, layout)
      end
    end

    # The vertical lines down each participant's column, drawn one row's worth
    # at a time so a column can start and stop with its owner.
    ClientLines = Data.define(:xs, :y1, :y2) do
      def bounds = [xs.min, y1, xs.max, y2]

      def translate(dx, dy) = with(xs: xs.map { |x| x + dx }, y1: y1 + dy, y2: y2 + dy)

      def draw(context)
        context.save do
          context.set_source_rgb(0.7, 0.7, 0.7)
          xs.each do |x|
            context.move_to(x, y1)
            context.line_to(x, y2)
            context.stroke
          end
        end
      end
    end

    # The faint horizontal line between two rows.
    Rule = Data.define(:x1, :x2, :y) do
      def bounds = [x1, y, x2, y]

      def translate(dx, dy) = with(x1: x1 + dx, x2: x2 + dx, y: y + dy)

      def draw(context)
        context.save do
          context.set_source_rgb(0.9, 0.9, 0.9)
          context.line_width = 0.5
          context.move_to(x1, y)
          context.line_to(x2, y)
          context.stroke
        end
      end
    end

    # A method call (arrowhead above the line) or its return (below), in red
    # if it is an error.
    Arrow = Data.define(
      :colour,
      :arrowhead,
      :x1,
      :x2,
      :y,
    ) do
      def bounds
        [[x1, x2].min, y - overhang(ABOVE), [x1, x2].max, y + overhang(BELOW)]
      end

      def translate(dx, dy) = with(x1: x1 + dx, x2: x2 + dx, y: y + dy)

      def draw(context)
        context.save do
          if colour
            context.set_source_rgb(colour.red, colour.green, colour.blue)
          end
          context.move_to(x1, y)
          context.line_to(x2, y)
          Arrowheads.half(context, arrowhead, x1 < x2)
          context.stroke
        end
      end

      private

        # The arrowhead sticks out five pixels on whichever side it points.
        def overhang(side)
          if arrowhead == side
            5
          else
            0
          end
        end
    end

    # A signal: a circle at the emitter, with arrows reaching out past the
    # outermost participant in both directions.
    SignalArrow = Data.define(
      :x1,
      :epicentre,
      :x2,
      :y,
    ) do
      def bounds = [[x1, x2].min, y - 5, [x1, x2].max, y + 5]

      def translate(dx, dy) = with(x1: x1 + dx, epicentre: epicentre + dx, x2: x2 + dx, y: y + dy)

      def draw(context) = Arrowheads.signal(
        context,
        epicentre,
        x1,
        x2,
        y,
      )
    end

    # A signal with a destination: the same circle, but one arrow only.
    DirectedSignalArrow = Data.define(:epicentre, :x, :y) do
      def bounds = [[epicentre, x].min, y - 5, [epicentre, x].max, y + 5]

      def translate(dx, dy) = with(epicentre: epicentre + dx, x: x + dx, y: y + dy)

      def draw(context)
        if x < epicentre
          Arrowheads.signal(
            context,
            epicentre,
            x,
            nil,
            y,
          )
        else
          Arrowheads.signal(
            context,
            epicentre,
            nil,
            x,
            y,
          )
        end
      end
    end

    # The dashed curve from a method call down to its return, captioned with
    # how long the call took.
    Arc = Data.define(
      :topx,
      :topy,
      :bottomx,
      :bottomy,
      :side,
      :caption,
    ) do
      def bounds
        (cx, _), (dx, _) = control_points
        [[topx, cx].min, topy, [bottomx, dx].max, bottomy + 5]
      end

      def translate(dx, dy) = with(topx: topx + dx, bottomx: bottomx + dx, topy: topy + dy, bottomy: bottomy + dy)

      def control_points
        [[topx + lean, topy + 10], [bottomx + lean, bottomy - 10]]
      end

      # Which way the curve bulges: away from the column the return travels
      # to, so two arcs on the same row cannot be confused.
      def lean
        if side == LEFT
          -60
        else
          60
        end
      end

      def draw(context)
        context.save do
          (cx, cy), (dx, dy) = control_points
          context.set_source_rgb(0.4, 0.7, 0.4)
          context.set_dash([3, 3], 0)
          context.move_to(topx, topy)
          context.curve_to(
            cx,
            cy,
            dx,
            dy,
            bottomx,
            bottomy,
          )
          context.stroke

          context.set_source_rgb(0, 0, 0)
          draw_caption(context, cx, dx)
        end
      end

      private

        # The caption sits beside the bottom of the curve, flipped to the other
        # side when the arc leans left so it never lands under the arc itself.
        def draw_caption(context, cx, dx)
          text = Diagram.layout(context, Marquee.escape(caption))
          text_width, = text.pixel_size
          centre = [bottomx, dx].min + ((bottomx - dx).abs / 2)
          if topx > cx
            context.move_to(centre - text_width, bottomy - 5)
          else
            context.move_to(centre, bottomy - 5)
          end
          Diagram.show_layout(context, text)
        end
    end

    # The pale band behind the selected message.
    Highlight = Data.define(:region) do
      def bounds = region

      def translate(dx, dy)
        with(region: [region[0] + dx, region[1] + dy, region[2] + dx, region[3] + dy])
      end

      def draw(context)
        context.save do
          x1, y1, x2, y2 = region
          context.set_source_rgb(0.8, 0.9, 1.0)
          context.rectangle(
            x1,
            y1,
            x2 - x1,
            y2 - y1,
          )
          context.fill
        end
      end
    end

    # The arrowheads, which are drawn relative to the current point and so
    # have to fiddle with it. Upstream's comment about "weird artifacts" is
    # why the left-pointing half moves rather than draws.
    module Arrowheads
      class << self
        def half(context, arrowhead, pointing_right)
          x, y = context.current_point
          tip_y = tip(arrowhead, y)
          if pointing_right
            context.move_to(x - 10, tip_y)
            context.line_to(x, y)
          else
            context.line_to(x + 10, tip_y)
            context.move_to(x, y)
          end
        end

        def tip(arrowhead, y)
          if arrowhead == ABOVE
            y - 5
          else
            y + 5
          end
        end

        def full(context, pointing_right)
          half(context, ABOVE, pointing_right)
          half(context, BELOW, pointing_right)
        end

        def signal(context, epicentre, left, right, y)
          context.new_path
          context.arc(
            epicentre,
            y,
            5,
            0,
            2 * Math::PI,
          )
          context.stroke

          if left
            context.move_to(left, y)
            full(context, false)
            context.line_to(epicentre - 5, y)
            context.stroke
          end

          if right
            context.move_to(epicentre + 5, y)
            context.line_to(right, y)
            full(context, true)
            context.stroke
          end
        end
      end
    end
  end
end
