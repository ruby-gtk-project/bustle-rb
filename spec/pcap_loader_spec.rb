# frozen_string_literal: true

require "bustle/pcap_loader"

# Ported from upstream's Test/PcapCrash.hs, the `test-pcap-crash` suite: a
# regression test for <https://bugs.freedesktop.org/show_bug.cgi?id=44714>.
#
# log-with-h.bustle is upstream's own fixture, copied across unchanged: a log
# containing a message with a Unix file handle in it, which used to make
# readPcap call `error`. Upstream's comment is explicit that it does not
# assert the log loads without warnings, "because we don't understand 'h', so
# we just skip it" — so neither does this. The fact being pinned is that an
# `h` does not take the loader down.

# Upstream's Test/data/log-with-h.bustle.
LOG_WITH_H = File.expand_path("fixtures/log-with-h.bustle", __dir__)

RSpec.describe Bustle::PcapLoader do
  it "reads a log containing a file handle rather than raising" do
    expect { Bustle::PcapLoader.read_pcap(LOG_WITH_H) }.not_to raise_error
  end

  it "returns warnings and a log for that file" do
    Bustle::PcapLoader.read_pcap(LOG_WITH_H).then do |warnings, log|
      expect(warnings).to be_an(Array)
      expect(log).not_to be_empty
    end
  end
end
