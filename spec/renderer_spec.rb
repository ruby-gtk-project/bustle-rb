# frozen_string_literal: true

require "set"

require "bustle/renderer"
require "bustle/types"

# Ported from upstream's Test/Renderer.hs, the `test-renderer` suite: two HUnit
# cases on participant disconnection and six pinning that incremental
# rendering matches all-at-once rendering.
#
# The logs are upstream's, event for event and timestamp for timestamp. The
# incremental log claims twenty-six well-known names on purpose: that is
# enough for the renderer to need to re-justify the diagram to the top, which
# is the case where `process_some` could disagree with `process`.
module RendererFixtures
  ACTIVE_SERVICE = Bustle::Types.unique_name(":1.1")
  OTHER_SERVICE = Bustle::Types.unique_name(":2.2")

  HELLO = Bustle::Types::Member.new(path: "/", interface: nil, member_name: "Hello")
  HI = Bustle::Types::Member.new(path: "/", interface: nil, member_name: "Hi")

  class << self
    # Upstream's `swaddle`: wraps bare events in the timestamped envelope the
    # renderer consumes. Upstream's message size is 0 and its received
    # message is a dummy, so the port's are 0 and empty.
    def swaddle(events, timestamps)
      events.zip(timestamps).map do |event, timestamp|
        Bustle::Types::Detailed.new(timestamp: timestamp, event: event, message_size: 0, body: [])
      end
    end

    def session_log_without_disconnect
      [
        Bustle::Types::Connected.new(actor: ACTIVE_SERVICE),
        Bustle::Types::Signal.new(sender: ACTIVE_SERVICE, signal_destination: nil, member: HELLO),
      ]
    end

    def session_log_with_disconnect
      session_log_without_disconnect + [Bustle::Types::Disconnected.new(actor: ACTIVE_SERVICE)]
    end

    def expected_participants = [[ACTIVE_SERVICE, Set.new]]

    # Upstream's `os`: "Foo.apotato" through "Foo.zpotato".
    def other_names
      ("a".."z").map { |letter| Bustle::Types.other_name("Foo.#{letter}potato") }
    end

    def bare_log
      [
        Bustle::Types::Connected.new(actor: ACTIVE_SERVICE),
        Bustle::Types::Signal.new(sender: ACTIVE_SERVICE, signal_destination: nil, member: HI),
        Bustle::Types::Connected.new(actor: OTHER_SERVICE),
      ] + claims + [call_to_first_name]
    end

    def claims
      other_names.map do |name|
        Bustle::Types::NameChanged.new(
          changed_name: name,
          change:       Bustle::Types::Claimed.new(new_owner: OTHER_SERVICE),
        )
      end
    end

    def call_to_first_name
      Bustle::Types::MethodCall.new(
        serial:      0,
        sender:      ACTIVE_SERVICE,
        destination: other_names.first,
        member:      HI,
      )
    end

    # Upstream's `sessionLog = swaddle bareLog [1,3..]`.
    def session_log = swaddle(bare_log, (1..).step(2))

    def full_result = Bustle::Renderer.process(session_log, [])

    # Upstream's `incrementalRR`: one message at a time through processSome
    # over a single renderer state, with the batches combined afterwards.
    def incremental_result
      Bustle::Renderer.state_new.then do |state|
        session_log.map { |message| Bustle::Renderer.process_some([message], [], state).first }
                   .reduce(Bustle::Renderer::Result.empty) { |merged, batch| merged.merge(batch) }
      end
    end

    def participants_of(log)
      Bustle::Renderer.process(swaddle(log, (1..)), []).applications.session_participants
    end
  end
end

RSpec.describe Bustle::Renderer do
  # Upstream: "Tests that services visible in a log are listed as participants
  # even if they disconnect from the bus before the end of the log. This is a
  # regression test for a bug I almost introduced."
  describe "disconnections don't affect participants" do
    it "lists one participant that does not disconnect" do
      expect(RendererFixtures.participants_of(RendererFixtures.session_log_without_disconnect))
        .to eq(RendererFixtures.expected_participants)
    end

    it "lists one participant that disconnects before the log ends" do
      expect(RendererFixtures.participants_of(RendererFixtures.session_log_with_disconnect))
        .to eq(RendererFixtures.expected_participants)
    end
  end

  # These six are what make live recording possible at all: the recorder feeds
  # messages through process_some as they arrive and merges the batches, so a
  # batch-by-batch rendering has to come out the same as rendering the whole
  # log at once.
  describe "incremental rendering matches all-at-once rendering" do
    it "agrees on the centre offset" do
      expect(RendererFixtures.incremental_result.centre_offset)
        .to eq(RendererFixtures.full_result.centre_offset)
    end

    it "agrees on the top offset" do
      expect(RendererFixtures.incremental_result.top_offset)
        .to eq(RendererFixtures.full_result.top_offset)
    end

    it "agrees on the shapes" do
      expect(RendererFixtures.incremental_result.shapes).to eq(RendererFixtures.full_result.shapes)
    end

    it "agrees on the regions" do
      expect(RendererFixtures.incremental_result.regions).to eq(RendererFixtures.full_result.regions)
    end

    it "agrees on the participants" do
      expect(RendererFixtures.incremental_result.applications)
        .to eq(RendererFixtures.full_result.applications)
    end

    it "agrees on the warnings" do
      expect(RendererFixtures.incremental_result.warnings).to eq(RendererFixtures.full_result.warnings)
    end
  end
end
