module RDig
  module Search

    # This class is used to search the index.
    # Call RDig::searcher to retrieve an instance ready for use.
    class Searcher
      include Ferret::Search

      # the query parser used to parse query strings
      attr_reader :query_parser

      # takes the ferret section of the rdig configuration as a parameter.
      def initialize(settings)
        @ferret_config = settings
        @query_parser = Ferret::QueryParser.new(settings.marshal_dump)
        ferret_searcher
      end

      # returns the Ferret::Search::IndexSearcher instance used internally.
      def ferret_searcher
        if @ferret_searcher and !@ferret_searcher.reader.latest?
          # reopen searcher
          @ferret_searcher.close
          @ferret_searcher = nil
        end
        unless @ferret_searcher
          @ferret_searcher = Ferret::Search::Searcher.new(@ferret_config.path)
          @query_parser.fields = @ferret_searcher.reader.field_names.to_a
        end
        @ferret_searcher
      end

      # run a search.
      # +query+ usually will be a user-entered string. See the Ferret query
      # language[http://ferret.davebalmain.com/api/classes/Ferret/QueryParser.html]
      # for more information on queries.
      # A Ferret::Search::Query instance may be given, too.
      #
      # Some of the more often used otions are:
      # offset:: first document in result list to retrieve (0-based). The default is 0.
      # limit:: number of documents to retrieve. The default is 10.
      # Please see the Ferret::Search::Searcher API for more options.
      # +advanced_extract+ when set to false will simply return first 200 characters
      # of the data, when set to true will iterate through the document matches and
      # return a small extract before and after the query
      def search(query, advanced_extract=false, options={})
        result = {}
        if advanced_extract
          str_query = query
        end

        query = query_parser.parse(query) if query.is_a?(String)
        RDig.logger.info "Query: #{query}"
        results = []
        searcher = ferret_searcher

        result[:hitcount] = searcher.search_each(query, options) do |doc_id, score|
          doc = searcher[doc_id]
          results << { :score => score,
                       :title => doc[:title],
                       :url => doc[:url],
                       :extract => build_extract(doc[:data], str_query) }
        end
        result[:list] = results
        result
      end

      def build_extract(data, query=nil, max_length=200)
        extract = []
        if query.nil?
          (data && data.length > max_length) ? data[0..max_length] : data
        else
          scannable_data = StringScanner.new(data)
          while !scannable_data.scan_until(/#{query}/i).nil?
            extract << get_extract_before_and_after(scannable_data, query, 15)
          end
          extract.join('...')
        end
      end

      def get_extract_before_and_after(data, query, words)
        data_before_match = data.pre_match.split
        words_before = []
        words.times { |w| words_before << data_before_match.pop }
        extract_before = words_before.compact.reverse.join(' ')
        "#{extract_before} #{data.matched} #{data.scan(/(\w+| ){1,#{words}}/)}"
      end
    end
  end
end
