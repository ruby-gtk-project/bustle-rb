# frozen_string_literal: true

require "adwaita"

require_relative "marquee"
require_relative "missing"
require_relative "stats"
require_relative "translation"

module Bustle
  # The statistics sidebar: three tables over the loaded log.
  #
  # Ported from upstream's Bustle/StatisticsPane.hs and the sidebarStack,
  # frequencySW, durationSW and sizeSW widgets in data/bustle.ui. Upstream
  # builds three GtkTreeViews over ListStores with hand-written cell
  # renderers; GTK4 replaces that with column views over Gio list stores and
  # factories, so each column says how to make a cell and how to fill it in.
  #
  # The frequency column really is a progress bar, as upstream's is, scaled
  # against the busiest member in the log and never quite empty so that a
  # member seen once still shows something.
  #
  # Every cell upstream renders is 7 points (`cellTextSizePoints := 7` in all
  # three of its addTextRenderer/addMemberRenderer helpers), which is what
  # makes a 30-character ellipsised member name fit beside four numeric
  # columns in a sidebar narrow enough to leave room for the diagram. A GTK4
  # column view has no equivalent property, so the same thing is said in CSS
  # against a class on the three views.
  class StatisticsPane
    # A GTK4 list model holds GObjects and nothing else, and upstream's rows
    # are value objects — Stats::FrequencyInfo, TimeInfo and SizeInfo are Ruby
    # Data, which no GType describes. So each row goes into the store inside
    # one of these, which is a GObject the store can be typed on, and every
    # factory asks it for the value object back.
    class Row < GLib::Object
      type_register

      attr_accessor :info

      class << self
        def of(info) = new.tap { |row| row.info = info }
      end
    end

    FREQUENCIES_PAGE = "frequencies"
    DURATIONS_PAGE = "durations"
    SIZES_PAGE = "sizes"

    TABLE_CSS_CLASS = "bustle-statistics"
    TABLE_POINT_SIZE = 7

    CSS = <<~CSS
      columnview.#{TABLE_CSS_CLASS},
      columnview.#{TABLE_CSS_CLASS} > header > button {
        font-size: #{TABLE_POINT_SIZE}pt;
      }
    CSS

    MINIMUM_BAR = 2
    BAR_RANGE = 98
    BAR_MINIMUM_WIDTH = 120
    MEMBER_WIDTH_CHARS = 30

    class << self
      # One provider for the whole display, added once however many windows
      # ask for it.
      def install_css
        unless @installed
          @installed = true
          Gtk::StyleContext.add_provider_for_display(
            Gdk::Display.default,
            css_provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end

      def css_provider
        @css_provider ||= Gtk::CssProvider.new.tap { |provider| provider.load(data: CSS) }
      end
    end

    def build
      StatisticsPane.install_css
      stack.tap do |pages|
        pages.add_titled(frequency_scroller, FREQUENCIES_PAGE, Bustle._("Frequencies"))
        pages.add_titled(duration_scroller, DURATIONS_PAGE, Bustle._("Durations"))
        pages.add_titled(size_scroller, SIZES_PAGE, Bustle._("Sizes"))

        frequency_scroller.child = frequency_view
        duration_scroller.child = duration_view
        size_scroller.child = size_view

        frequency_view.tap do |view|
          view.append_column(frequency_member_column)
          view.append_column(frequency_count_column)
        end

        duration_view.tap do |view|
          view.append_column(duration_member_column)
          view.append_column(duration_total_column)
          view.append_column(duration_calls_column)
          view.append_column(duration_mean_column)
        end

        size_view.tap do |view|
          view.append_column(size_member_column)
          view.append_column(size_smallest_column)
          view.append_column(size_mean_column)
          view.append_column(size_largest_column)
        end
      end
    end

    # The two buses are conflated into one set of tables, as upstream's
    # statsPaneSetMessages does with the same two arguments.
    def set_messages(session_messages, system_messages)
      (session_messages + system_messages).then do |all_messages|
        Stats.frequencies(all_messages).tap do |frequencies|
          @busiest = frequencies.map(&:frequency).max
          fill(frequency_store, frequencies)
        end
        fill(duration_store, Stats.method_times(all_messages))
        fill(size_store, Stats.message_sizes(all_messages))
      end
    end

    def stack
      @stack ||= Gtk::Stack.new.tap do |pages|
        pages.transition_type = :crossfade
        pages.vexpand = true
      end
    end

    def frequency_scroller = @frequency_scroller ||= scroller

    def duration_scroller = @duration_scroller ||= scroller

    def size_scroller = @size_scroller ||= scroller

    def frequency_store = @frequency_store ||= Gio::ListStore.new(Row)

    def duration_store = @duration_store ||= Gio::ListStore.new(Row)

    def size_store = @size_store ||= Gio::ListStore.new(Row)

    def frequency_view = @frequency_view ||= column_view(frequency_store)

    def duration_view = @duration_view ||= column_view(duration_store)

    def size_view = @size_view ||= column_view(size_store)

    def frequency_member_column
      @frequency_member_column ||= member_column(Bustle._("Member")) do |info|
        [tally_name(info.type), Marquee.format_member(info.interface, info.member)]
      end
    end

    # Upstream's `treeViewColumnSetMinWidth 120` is a floor, not a width: the
    # bar is never narrower than 120px and grows with the sidebar. A GTK4
    # column view has no minimum-width property, so the floor is the bar's own
    # minimum size (`BAR_MINIMUM_WIDTH`, set in the factory) and the column
    # takes it from there — a `fixed_width` here would make 120 a ceiling too.
    def frequency_count_column
      @frequency_count_column ||= Gtk::ColumnViewColumn.new(Bustle._("Frequency"), frequency_bar_factory)
    end

    def duration_member_column
      @duration_member_column ||= member_column(Bustle._("Method")) do |info|
        [nil, Marquee.format_member(info.interface, info.method_name)]
      end
    end

    def duration_total_column
      @duration_total_column ||= text_column(Bustle._("Total")) do |info|
        format(Bustle._("%.1f ms"), info.total_time)
      end
    end

    def duration_calls_column
      @duration_calls_column ||= text_column(Bustle._("Calls")) { |info| info.call_frequency.to_s }
    end

    def duration_mean_column
      @duration_mean_column ||= text_column(Bustle._("Mean")) do |info|
        format(Bustle._("%.1f ms"), info.mean_call_time)
      end
    end

    def size_member_column
      @size_member_column ||= member_column(Bustle._("Member")) do |info|
        [size_type_name(info.type), size_member_markup(info)]
      end
    end

    def size_smallest_column
      @size_smallest_column ||= text_column(Bustle._("Smallest")) { |info| Missing.format_size(info.min_size) }
    end

    def size_mean_column
      @size_mean_column ||= text_column(Bustle._("Mean")) { |info| Missing.format_size(info.mean_size) }
    end

    def size_largest_column
      @size_largest_column ||= text_column(Bustle._("Largest")) { |info| Missing.format_size(info.max_size) }
    end

    private

      def fill(store, rows)
        store.remove_all
        rows.each { |row| store.append(Row.of(row)) }
      end

      # What a factory's bound list item is really showing.
      def value_of(item) = item.item.info

      def scroller
        Gtk::ScrolledWindow.new.tap do |sw|
          sw.hexpand = true
          sw.vexpand = true
        end
      end

      def column_view(store)
        Gtk::ColumnView.new(Gtk::NoSelection.new(store)).tap do |view|
          view.show_column_separators = true
          view.add_css_class("data-table")
          view.add_css_class(TABLE_CSS_CLASS)
        end
      end

      # The member cell is upstream's two renderers in one: the kind of
      # message, dimmed, then the member itself ellipsized from the left so
      # the method name stays readable when the interface does not fit.
      def member_column(title, &describe)
        Gtk::ColumnViewColumn.new(title, member_factory(&describe)).tap do |col|
          col.expand = true
          col.resizable = true
        end
      end

      def member_factory(&describe)
        Gtk::SignalListItemFactory.new.tap do |factory|
          factory.signal_connect("setup") { |_factory, item| item.child = member_cell }
          factory.signal_connect("bind") do |_factory, item|
            kind, member = describe.call(value_of(item))
            item.child.first_child.tap do |kind_label|
              kind_label.label = kind.to_s
              kind_label.visible = !kind.nil?
            end
            item.child.last_child.label = member.to_markup
          end
        end
      end

      def member_cell
        Gtk::Box.new(:horizontal, 6).tap do |box|
          box.append(
            Gtk::Label.new.tap do |label|
              label.add_css_class("dim-label")
              label.xalign = 0
            end,
          )
          box.append(
            Gtk::Label.new.tap do |label|
              label.use_markup = true
              label.ellipsize = :start
              label.width_chars = MEMBER_WIDTH_CHARS
              label.xalign = 1
              label.hexpand = true
            end,
          )
        end
      end

      def text_column(title, &format_cell)
        Gtk::ColumnViewColumn.new(title, text_factory(&format_cell))
      end

      def text_factory(&format_cell)
        Gtk::SignalListItemFactory.new.tap do |factory|
          factory.signal_connect("setup") do |_factory, item|
            item.child = Gtk::Label.new.tap { |label| label.xalign = 1 }
          end
          factory.signal_connect("bind") { |_factory, item| item.child.label = format_cell.call(value_of(item)) }
        end
      end

      def frequency_bar_factory
        Gtk::SignalListItemFactory.new.tap do |factory|
          factory.signal_connect("setup") do |_factory, item|
            item.child = Gtk::ProgressBar.new.tap do |bar|
              bar.show_text = true
              bar.set_size_request(BAR_MINIMUM_WIDTH, -1)
            end
          end
          factory.signal_connect("bind") do |_factory, item|
            item.child.fraction = bar_fraction(value_of(item).frequency)
            item.child.text = value_of(item).frequency.to_s
          end
        end
      end

      # Scaled against the busiest member, with a floor so that the rarest
      # member in the log still draws a sliver.
      def bar_fraction(count)
        (MINIMUM_BAR + (count * BAR_RANGE / busiest)) / 100.0
      end

      def busiest = @busiest ||= 1

      def tally_name(type)
        case type
        when Stats::METHOD then Bustle._("Method")
        when Stats::SIGNAL then Bustle._("Signal")
        end
      end

      def size_type_name(type)
        case type
        when Stats::SIZE_CALL then Bustle._("Method call")
        when Stats::SIZE_RETURN then Bustle._("Method return")
        when Stats::SIZE_ERROR then Bustle._("Error")
        when Stats::SIZE_SIGNAL then Bustle._("Signal")
        end
      end

      # Returns are italicised and errors reddened, exactly as upstream's
      # formatSizeInfoMember does, so the three rows for one method are
      # distinguishable at a glance.
      def size_member_markup(info)
        Marquee.format_member(info.interface, info.name).then do |member|
          case info.type
          when Stats::SIZE_RETURN then Marquee.i(member)
          when Stats::SIZE_ERROR then Marquee.red(member)
          else member
          end
        end
      end
  end
end
