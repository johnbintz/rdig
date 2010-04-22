module RDig
  module Index
    # used by the crawler to build the ferret index
    class Indexer
      include MonitorMixin

      def initialize(settings)
        @config = settings

        @url_popularity = {}

        field_infos = Ferret::Index::FieldInfos.new

        @config.weightings.each do |field, weight|
          field_infos.add_field field, :boost => weight
        end

        index_writer_options = {
          :path     => settings.path,
          :create   => settings.create,
          :analyzer => settings.analyzer,
          :field_infos => field_infos,
          :id_field => :url,
          :key => :url
        }

        @index = Ferret::Index::Index.new(index_writer_options)
        super() # scary, MonitorMixin won't initialize if we don't call super() here (parens matter)
      end

      def add_to_index(document)
        RDig.logger.debug "add to index: #{document.uri.to_s}"
        @config.rewrite_uri.call(document.uri) if @config.rewrite_uri
        # all stored and tokenized, should be ferret defaults
        doc = {
          :url   => document.uri.to_s,
          :path  => document.uri.path
        }

        if document.links
          document.links.each do |link|
            if !@url_popularity[link]
              @url_popularity[link] = 0
            end

            @url_popularity[link] += 1
          end
        end

        @config.fields.each do |field|
          doc[field] = document.content[field]
        end

        synchronize do
          @index << doc
        end
      end
      alias :<< :add_to_index

      def close
        RDig.logger.debug "calculating boosts..."
        synchronize do
          (0...@index.size()).each do |i|
            doc = @index[i].load
            total_boost = 0
            @url_popularity.each do |link, boost|
              if doc[:url][link]
                total_boost += (boost / 100)
              end
            end

            @config.boosts.each do |regexp, boost|
              total_boost += boost if (doc[:url][regexp])
            end

            d = Ferret::Document.new(total_boost)
            doc.keys.each do |k|
              d[k] = doc[k]
            end

            @index.delete i
            @index << d
          end
        end

        @index.optimize
        @index.close
        @index = nil
      end
    end

  end
end
