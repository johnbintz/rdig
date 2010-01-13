module RDig
  module Index
    # used by the crawler to build the ferret index
    class Indexer
      include MonitorMixin

      def initialize(settings)
        @config = settings

        field_infos = Ferret::Index::FieldInfos.new

        @config.weightings.each do |field, weight|
          field_infos.add_field field, :boost => weight
        end

        @index_writer = Ferret::Index::IndexWriter.new(
                          :path     => settings.path,
                          :create   => settings.create,
                          :analyzer => settings.analyzer,
                          :field_infos => field_infos)
        super() # scary, MonitorMixin won't initialize if we don't call super() here (parens matter)
      end

      def add_to_index(document)
        RDig.logger.debug "add to index: #{document.uri.to_s}"
        @config.rewrite_uri.call(document.uri) if @config.rewrite_uri
        # all stored and tokenized, should be ferret defaults
        doc = {
          :url   => document.uri.to_s
        }

        @config.fields.each do |field|
          doc[field] = document.content[field]
        end

        synchronize do
          @index_writer << doc
        end
      end
      alias :<< :add_to_index

      def close
        @index_writer.optimize
        @index_writer.close
        @index_writer = nil
      end
    end

  end
end
