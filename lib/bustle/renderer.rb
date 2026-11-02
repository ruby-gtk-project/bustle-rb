# frozen_string_literal: true

require "set"

require_relative "diagram"
require_relative "regions"
require_relative "types"

module Bustle
  # Turns a log into a sequence diagram.
  #
  # Ported from upstream's Bustle/Renderer.hs. The renderer walks the session
  # and system bus logs interleaved by timestamp, keeping one column per
  # participant per bus — session bus columns march rightwards from the
  # timestamp column, system bus columns leftwards from its left edge — and
  # emits the shapes for each message as it goes, along with the clickable
  # region each message occupies.
  #
  # Three details are worth knowing. A method return is drawn against the
  # coordinates its call was drawn at, so the renderer remembers every
  # unanswered call. Column headers are re-emitted every 400 pixels, which is
  # why the row advances by more than one event height now and then. And a
  # name that appears without the renderer ever seeing it claimed — routine in
  # a log that started mid-conversation — gets a made-up unique name and a
  # warning, rather than losing the message.
  module Renderer
    SESSION_BUS = :session
    SYSTEM_BUS = :system

    LABEL_INTERVAL = 400
    MARGIN_FOR_HEADERS = 35

    # Where a participant's column is, if it has one. A disconnected
    # participant keeps its old column as a FORMER one so a late message can
    # still be drawn in the right place.
    NO_COLUMN = :none
    CURRENT_COLUMN = :current
    FORMER_COLUMN = :former

    Column = Data.define(:kind, :x) do
      def current_x
        if kind == CURRENT_COLUMN
          x
        end
      end

      def ever_x
        case kind
        when NO_COLUMN then nil
        else x
        end
      end
    end

    class << self
      def column_none = Column.new(kind: NO_COLUMN, x: nil)

      def column_current(x) = Column.new(kind: CURRENT_COLUMN, x:)

      def column_former(x) = Column.new(kind: FORMER_COLUMN, x:)

      def state_new = State.build(Set.new, Set.new)

      # Renders two complete logs, reporting who took part so the filter
      # dialog has something to list.
      def process(session_log, system_log)
        process_some(session_log, system_log, state_new).first
      end

      # Re-renders with some session bus participants hidden, which is what
      # the filter dialog asks for.
      def process_with_filters(session, system)
        session_log, session_filter = session
        system_log, system_filter = system
        process_some(session_log, system_log, State.build(session_filter, system_filter)).first
      end

      # Renders freshly-arrived messages on top of the state left over from
      # the last batch, returning the new output and the state to re-use.
      def process_some(session_log, system_log, state)
        Processor.new(state).run(session_log, system_log).then { |result| [result, state] }
      end

      def describe_bus(bus)
        case bus
        when SESSION_BUS then "session"
        when SYSTEM_BUS then "system"
        end
      end
    end

    # Who appeared on each bus, and in which column.
    class Participants
      def initialize(session: {}, system: {})
        @session = session
        @system = system
      end

      attr_reader :session, :system

      # The session bus participants in column order: the order the filter
      # dialog lists them in, and the order they appear left to right.
      def session_participants
        session.sort_by { |(column, unique_name), _names| [column, unique_name.to_s] }
               .map { |(_column, unique_name), names| [unique_name, names] }
      end

      def merge(other)
        Participants.new(
          session: merge_maps(session, other.session),
          system:  merge_maps(system, other.system),
        )
      end

      private

        def merge_maps(one, other)
          one.merge(other) { |_key, names, more| names | more }
        end
    end

    # One batch of rendering: the shapes, the clickable regions, who took
    # part, and anything odd the renderer noticed on the way.
    class Result
      EMPTY_OFFSET = 0.0

      def initialize(centre_offset:, top_offset:, shapes:, regions:, applications:, warnings:)
        @centre_offset = centre_offset
        @top_offset = top_offset
        @shapes = shapes
        @regions = regions
        @applications = applications
        @warnings = warnings
      end

      class << self
        def empty
          new(
            centre_offset: EMPTY_OFFSET,
            top_offset:    EMPTY_OFFSET,
            shapes:        [],
            regions:       [],
            applications:  Participants.new,
            warnings:      [],
          )
        end
      end

      attr_reader :centre_offset, :top_offset, :shapes, :regions, :applications, :warnings

      # Combining two batches is unpleasant and upstream says so: the second
      # batch may have discovered a participant with ten names where the first
      # had one, so one or other batch has to be shifted down and across to
      # line up with the other.
      def merge(other)
        centre = [centre_offset, other.centre_offset].max
        top = [top_offset, other.top_offset].max
        Result.new(
          centre_offset: centre,
          top_offset:    top,
          shapes:        shifted_shapes(centre, top) + other.shifted_shapes(centre, top),
          regions:       shifted_regions(top) + other.shifted_regions(top),
          applications:  applications.merge(other.applications),
          warnings:      warnings + other.warnings,
        )
      end

      def shifted_shapes(centre, top)
        Diagram.translate_diagram([centre - centre_offset, top - top_offset], shapes)
      end

      def shifted_regions(top)
        Regions.translate_regions(top - top_offset, regions)
      end
    end

    # What one participant is called, and where its column is.
    class ApplicationInfo
      attr_accessor :column, :current_names, :ever_names

      def initialize
        @column = Renderer.column_none
        @current_names = Set.new
        @ever_names = Set.new
      end
    end

    # The renderer's knowledge of one bus.
    class BusState
      attr_accessor :apps, :first_column, :next_column, :columns_in_use, :pending, :ignored_names

      def initialize(ignored_names, first_column)
        @apps = {}
        @first_column = first_column
        @next_column = first_column
        @columns_in_use = Set.new
        @pending = {}
        @ignored_names = ignored_names
      end
    end

    # Everything that has to survive from one batch of messages to the next.
    class State
      attr_accessor :session_bus_state, :system_bus_state, :row, :most_recent_labels, :start_time

      class << self
        def build(session_filter, system_filter)
          new(
            BusState.new(session_filter, Diagram::TIMESTAMP_AND_MEMBER_WIDTH + Diagram::FIRST_COLUMN_OFFSET),
            BusState.new(system_filter, -Diagram::FIRST_COLUMN_OFFSET),
          )
        end
      end

      def initialize(session_bus_state, system_bus_state)
        @session_bus_state = session_bus_state
        @system_bus_state = system_bus_state
        @row = 0.0
        @most_recent_labels = 0.0
        @start_time = 0
      end

      def bus_state(bus)
        case bus
        when SESSION_BUS then session_bus_state
        else system_bus_state
        end
      end
    end

    # The engine. One instance renders one batch of messages against a state
    # it is allowed to modify, which is upstream's Writer-over-State monad
    # written out the long way.
    class Processor
      def initialize(state)
        @state = state
        @shapes = []
        @regions = []
        @warnings = []
      end

      def run(session_log, system_log)
        combine(session_log, system_log).each { |bus, detailed| process_one(bus, detailed) }
        build_result
      end

      private

        def build_result
          translation, shapes = Diagram.top_left_justify(@shapes)
          Result.new(
            centre_offset: translation[0],
            top_offset:    translation[1],
            shapes:,
            regions:       Regions.translate_regions(translation[1], @regions),
            applications:  participants,
            warnings:      @warnings,
          )
        end

        def participants
          Participants.new(
            session: columns_of(@state.session_bus_state),
            system:  columns_of(@state.system_bus_state),
          )
        end

        def columns_of(bus_state)
          bus_state.apps.filter_map do |unique_name, info|
            info.column.ever_x.then do |column|
              if column
                [[column, unique_name], info.ever_names]
              end
            end
          end.to_h
        end

        # Interleaves the two buses' messages by timestamp. Both logs are
        # already sorted, so this is a merge; the system bus wins a tie, as
        # upstream's comparison does.
        def combine(session_log, system_log)
          session = session_log.dup
          system = system_log.dup
          combined = []
          until session.empty? && system.empty?
            if system.empty? || (!session.empty? && session.first.timestamp < system.first.timestamp)
              combined << [SESSION_BUS, session.shift]
            else
              combined << [SYSTEM_BUS, system.shift]
            end
          end
          combined
        end

        def process_one(bus, detailed)
          if detailed.noc?
            process_noc(bus, detailed.event)
          else
            process_message(bus, detailed)
          end
        end

        def process_noc(bus, noc)
          case noc
          when Types::Connected then add_unique(bus, noc.actor)
          when Types::Disconnected then remove_unique(bus, noc.actor)
          when Types::NameChanged then update_apps(bus, noc.changed_name, noc.change)
          end
        end

        def process_message(bus, detailed)
          if show?(bus, detailed.event)
            draw_message(bus, detailed)
          end
        end

        def draw_message(bus, detailed)
          case detailed.event
          when Types::Signal then draw_signal(bus, detailed)
          when Types::MethodCall then draw_method_call(bus, detailed)
          when Types::MethodReturn then draw_reply(bus, detailed) { |reply| method_like(
            nil,
            Diagram::BELOW,
            bus,
            reply,
          ) }
          when Types::ErrorReturn
            draw_reply(bus, detailed) { |reply| method_like(
              Diagram::ERROR_COLOUR,
              Diagram::BELOW,
              bus,
              reply,
            ) }
          end
        end

        def draw_signal(bus, detailed)
          advance
          relative_timestamp(detailed)
          member_name(detailed, false)
          signal(bus, detailed)
          add_message_region(detailed)
        end

        def draw_method_call(bus, detailed)
          advance
          relative_timestamp(detailed)
          member_name(detailed, false)
          method_like(
            nil,
            Diagram::ABOVE,
            bus,
            detailed,
          )
          add_pending(bus, detailed)
          add_message_region(detailed)
        end

        # A reply with no call in the log is dropped: there is nowhere to draw
        # it from, and no member name to label it with.
        def draw_reply(bus, detailed, &draw_arrow)
          find_call_coordinates(bus, detailed.event.in_reply_to).then do |found|
            if found
              call, coordinates = found
              advance
              relative_timestamp(detailed)
              member_name(call, true)
              draw_arrow.call(detailed)
              return_arc(
                bus,
                detailed,
                coordinates,
                detailed.timestamp - call.timestamp,
              )
              add_message_region(detailed)
            end
          end
        end

        def advance = advance_by(Diagram::EVENT_HEIGHT)

        # Moves down a row, drawing the rule between the rows and extending
        # every live column through the new row. Every LABEL_INTERVAL pixels
        # the column headers are repeated, which costs an extra row.
        def advance_by(distance)
          relabel_if_needed
          current = @state.row
          @state.row += distance
          shape(Diagram::Rule.new(x1: left_margin, x2: right_margin, y: current + 15))
          live_columns.then do |columns|
            unless columns.empty?
              shape(Diagram::ClientLines.new(xs: columns, y1: current + 15, y2: @state.row + 15))
            end
          end
        end

        def relabel_if_needed
          current = @state.row
          if current - @state.most_recent_labels > LABEL_INTERVAL
            labelled = labelled_columns.map { |x, unique_name, names| [x, best_names(unique_name, names)] }
            height, shapes = Diagram.headers(labelled, current + 20)
            @shapes.concat(shapes)
            @state.most_recent_labels = current + height + 10
            @state.row += height + 10
          end
        end

        def labelled_columns
          [SESSION_BUS, SYSTEM_BUS].flat_map do |bus|
            @state.bus_state(bus).apps.filter_map do |unique_name, info|
              info.column.current_x.then do |x|
                if x
                  [x, unique_name, info.current_names]
                end
              end
            end
          end
        end

        def live_columns
          [SESSION_BUS, SYSTEM_BUS].flat_map do |bus|
            @state.bus_state(bus).apps.values.filter_map { |info| info.column.current_x }
          end
        end

        # The rules stop short of the outermost column, leaving room for a new
        # participant's headers to be drawn without overlapping them.
        def left_margin
          edgemost_app(SYSTEM_BUS).then do |x|
            if x
              x - MARGIN_FOR_HEADERS
            else
              0
            end
          end
        end

        def right_margin
          edgemost_app(SESSION_BUS).then do |x|
            if x
              x + MARGIN_FOR_HEADERS
            else
              Diagram::TIMESTAMP_AND_MEMBER_WIDTH
            end
          end
        end

        def edgemost_app(bus)
          @state.bus_state(bus).columns_in_use.then do |columns|
            if columns.empty?
              nil
            elsif bus == SESSION_BUS
              columns.max
            else
              columns.min
            end
          end
        end

        def method_like(colour, arrowhead, bus, detailed)
          shape(
            Diagram::Arrow.new(
              colour:,
              arrowhead:,
              x1: sender_coordinate(bus, detailed),
              x2: destination_coordinate(bus, detailed),
              y: @state.row,
            ),
          )
        end

        # An undirected signal reaches out past the outermost participant on
        # both sides; a directed one points at its destination's column.
        def signal(bus, detailed)
          emitter = sender_coordinate(bus, detailed)
          signal_destination_coordinate(bus, detailed).then do |target|
            if target
              shape(Diagram::DirectedSignalArrow.new(epicentre: emitter, x: target, y: @state.row))
            else
              shape(broadcast_arrow(bus, emitter))
            end
          end
        end

        def broadcast_arrow(bus, emitter)
          x1, x2 = [edgemost_app(bus), @state.bus_state(bus).first_column].sort
          Diagram::SignalArrow.new(x1: x1 - 20, epicentre: emitter, x2: x2 + 20, y: @state.row)
        end

        def return_arc(bus, reply, coordinates, duration)
          call_x, call_y = coordinates
          sender_x = sender_coordinate(bus, reply)
          shape(
            Diagram::Arc.new(
              topx:    call_x,
              topy:    call_y,
              bottomx: sender_x,
              bottomy: @state.row,
              side:    arc_side(destination_coordinate(bus, reply), sender_x),
              caption: "#{Types.us_to_ms(duration)}ms",
            ),
          )
        end

        def arc_side(destination_x, sender_x)
          if destination_x > sender_x
            Diagram::LEFT
          else
            Diagram::RIGHT
          end
        end

        def member_name(detailed, is_return)
          detailed.event.member.then do |member|
            shape(
              Diagram.member_label(
                member.path,
                member.interface,
                member.member_name,
                is_return,
                @state.row,
              ),
            )
          end
        end

        # Timestamps are shown relative to the first message in the log, which
        # is a lot easier to read than the wall clock.
        def relative_timestamp(detailed)
          shape(Diagram.timestamp_label("#{Types.us_to_ms(time_offset(detailed.timestamp))}ms", @state.row))
        end

        def time_offset(microseconds)
          if @state.start_time.zero?
            @state.start_time = microseconds
            0
          else
            microseconds - @state.start_time
          end
        end

        # The row points at the middle of the event, so the clickable stripe
        # reaches half an event height either side of it.
        def add_message_region(detailed)
          @regions << Regions::Region.new(
            stripe: Regions::Stripe.new(
              top:    @state.row - (Diagram::EVENT_HEIGHT / 2),
              bottom: @state.row + (Diagram::EVENT_HEIGHT / 2),
            ),
            value:  detailed,
          )
        end

        def add_pending(bus, detailed)
          @state.bus_state(bus).pending[detailed] = [destination_coordinate(bus, detailed), @state.row]
        end

        def find_call_coordinates(bus, call)
          if call
            @state.bus_state(bus).pending.delete(call).then do |coordinates|
              if coordinates
                [call, coordinates]
              end
            end
          end
        end

        def sender_coordinate(bus, detailed) = app_coordinate(bus, detailed.event.sender)

        def destination_coordinate(bus, detailed) = app_coordinate(bus, detailed.event.destination)

        def signal_destination_coordinate(bus, detailed)
          detailed.event.signal_destination.then do |name|
            if name
              app_coordinate(bus, name)
            end
          end
        end

        # Finds a name's column, allocating one if this is the first time the
        # name has been seen in anger.
        def app_coordinate(bus, name)
          unique_name, info = lookup_app(bus, name)
          case info.column.kind
          when CURRENT_COLUMN then info.column.x
          when NO_COLUMN then assign_column(bus, unique_name, info.current_names)
          else reappeared_coordinate(
            bus,
            name,
            unique_name,
            info,
          )
          end
        end

        def reappeared_coordinate(bus, name, unique_name, info)
          warn("#{name} (owned by #{unique_name}) spontaneously reappeared")
          info.column.x.then do |x|
            if x
              x
            else
              assign_column(bus, unique_name, info.current_names)
            end
          end
        end

        # Session bus columns are allocated rightwards, system bus columns
        # leftwards, so the two buses grow away from the shared timestamp and
        # member columns in the middle.
        def assign_column(bus, unique_name, other_names)
          bus_state = @state.bus_state(bus)
          x = bus_state.next_column
          bus_state.next_column = next_column_after(bus, x)
          bus_state.columns_in_use << x
          bus_state.apps[unique_name].column = Renderer.column_current(x)
          draw_new_column(x, best_names(unique_name, other_names))
          x
        end

        def next_column_after(bus, x)
          case bus
          when SESSION_BUS then x + Diagram::COLUMN_WIDTH
          else x - Diagram::COLUMN_WIDTH
          end
        end

        def draw_new_column(x, names)
          shape(Diagram::Header.new(names:, x:, y: @state.row - (10 + Diagram.header_height(names))))
          shape(Diagram::ClientLines.new(xs: [x], y1: @state.row - 5, y2: @state.row + 15))
        end

        def lookup_app(bus, name)
          if name.unique?
            [name, lookup_unique_name(bus, name)]
          else
            lookup_other_name(bus, name)
          end
        end

        # A pcap log carries no explicit notification for unique names, so the
        # first message from one is also where we learn it exists.
        def lookup_unique_name(bus, unique_name)
          @state.bus_state(bus).apps[unique_name] || add_unique(bus, unique_name)
        end

        def lookup_other_name(bus, other_name)
          owners = @state.bus_state(bus).apps.select { |_unique, info| info.current_names.include?(other_name) }
          case owners.length
          when 1 then owners.first
          when 0 then invent_owner(bus, other_name)
          else report_several_owners(bus, other_name, owners)
          end
        end

        # No owner at all means the log is missing the name's claim, which
        # dbus-monitor logs routinely are; invent a unique name so the
        # messages still have a column to live in.
        def invent_owner(bus, other_name)
          warn(
            "'#{other_name}' appeared unheralded on the " \
            "#{Renderer.describe_bus(bus)} bus; making something up...",
          )
          unique_name = unused_fake_name(bus)
          add_unique(bus, unique_name)
          add_other(bus, other_name, unique_name)
          [unique_name, lookup_unique_name(bus, unique_name)]
        end

        def unused_fake_name(bus)
          (1..).lazy.map { |index| Types.fake_unique_name(index.to_s) }
                    .reject { |candidate| @state.bus_state(bus).apps.key?(candidate) }
                    .first
        end

        # Several owners means the log told us something impossible, which
        # happens with dbus-monitor logs that never dumped the initial name
        # list. Upstream picks the first and says so; so does the port.
        def report_several_owners(bus, other_name, owners)
          warn("#{other_name} owned by several apps: #{owners.keys.map(&:to_s).join(", ")}")
          owners.first
        end

        def add_unique(bus, unique_name)
          if @state.bus_state(bus).apps.key?(unique_name)
            warn("Unique name '#{unique_name}' apparently connected to the bus twice")
          end
          ApplicationInfo.new.tap { |info| @state.bus_state(bus).apps[unique_name] = info }
        end

        # A departed participant keeps its column for the record but frees it
        # from the set in use, so the rules stop extending out to it.
        def remove_unique(bus, unique_name)
          info = lookup_unique_name(bus, unique_name)
          info.column.current_x.then do |x|
            info.column = Renderer.column_former(x)
            if x
              @state.bus_state(bus).columns_in_use.delete(x)
            end
          end
        end

        def update_apps(bus, other_name, change)
          case change
          when Types::Claimed then add_other(bus, other_name, change.new_owner)
          when Types::Stolen
            remove_other(bus, other_name, change.old_owner)
            add_other(bus, other_name, change.new_owner)
          when Types::Released then remove_other(bus, other_name, change.old_owner)
          end
        end

        def add_other(bus, other_name, unique_name)
          lookup_unique_name(bus, unique_name).then do |info|
            info.current_names << other_name
            info.ever_names << other_name
          end
        end

        def remove_other(bus, other_name, unique_name)
          lookup_unique_name(bus, unique_name).current_names.delete(other_name)
        end

        # Looks every mentioned name up even when nothing is filtered, because
        # the lookup is also how a name first becomes known to the renderer.
        def show?(bus, message)
          names = Types.mentioned_names(message).map { |name| lookup_app(bus, name).first }
          @state.bus_state(bus).ignored_names.intersection(Set.new(names)).empty?
        end

        # A participant is labelled with the last component of its well-known
        # names, longest first, falling back to its unique name when it has
        # none — ":1.42" is not informative, but it is all there is.
        def best_names(unique_name, other_names)
          if other_names.empty?
            [unique_name.to_s]
          else
            other_names.map { |name| name.to_s.split(".").last }
                       .sort_by { |name| [-name.length, name] }
          end
        end

        def shape(drawn) = @shapes << drawn

        def warn(warning) = @warnings << warning
    end
  end
end
