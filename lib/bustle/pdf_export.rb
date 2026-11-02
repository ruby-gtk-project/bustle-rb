# frozen_string_literal: true

require "adwaita"

require_relative "diagram"
require_relative "translation"

module Bustle
  # Writes the diagram out as a PDF.
  #
  # Ported from upstream's saveToPDFDialogue in Bustle/UI.hs: a save chooser
  # suggesting the log's own name with a .pdf extension, defaulting to the
  # directory the log came from, and then the same shapes the canvas draws
  # rendered onto a PDF surface the size of the whole diagram. Nothing is
  # scaled or paginated — upstream's PDFs are one very tall page, and so are
  # these.
  class PdfExport
    PDF_EXTENSION = ".pdf"

    def initialize(shapes:, suggested_name:, directory: nil, on_error: nil, on_success: nil)
      @shapes = shapes
      @suggested_name = suggested_name
      @directory = directory
      @on_error = on_error
      @on_success = on_success
    end

    def present(parent)
      dialog.save(parent, nil) do |_source, result|
        export(dialog.save_finish(result).path)
      rescue GLib::Error
        # Dismissing the chooser is not an error worth reporting.
        nil
      end
    end

    def dialog
      @dialog ||= Gtk::FileDialog.new.tap do |chooser|
        chooser.title = Bustle._("Export as PDF")
        chooser.modal = true
        chooser.initial_name = "#{@suggested_name}#{PDF_EXTENSION}"
        if @directory
          chooser.initial_folder = Gio::File.new_for_path(@directory)
        end
      end
    end

    private

      def export(path)
        width, height = Diagram.diagram_dimensions(@shapes)
        render(path, width, height)
        @on_success&.call(path)
      rescue SystemCallError, IOError, Cairo::Error => e
        @on_error&.call(format(Bustle._("Couldn't export log as PDF: %s"), e.message))
      end

      def render(path, width, height)
        Cairo::PDFSurface.new(path, width, height).tap do |surface|
          Cairo::Context.new(surface).tap do |context|
            Diagram.draw_diagram(context, @shapes)
          end
          surface.finish
        end
      end
  end
end
