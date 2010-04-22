module RDig
  module ContentExtractors
    # Extract text from pdf content.
    #
    # Requires the pdftotext and pdfinfo utilities from the 
    # xpdf-utils package
    # (on debian and friends do 'apt-get install xpdf-utils')
    #
    class PdfContentExtractor < ContentExtractor
      include ExternalAppHelper
      
      def initialize(config)
        super(config.pdf)
        @pattern = /^application\/pdf/
        
        @available = true
        
        %w{pdftotext pdfinfo}.each do |program|
          if config.pdf_tools_path
            program = "#{config.pdf_tools_path}#{program}"
          end
          
          if %x{#{program} -h 2>&1} =~ /Copyright 1996/ 
            instance_variable_set("@#{program}".to_sym, program)
          else
            @available = false 
            break
          end
        end
      end
 
      def process(content, default_title = nil)
        result = {}
        as_file(content) do |file|
          result[:content] = get_content(file.path).strip
          result[:title] = get_title(file.path) || default_title
        end
        result
      end

      def get_content(path_to_tempfile)
        %x{#{@pdftotext} -enc UTF-8 '#{path_to_tempfile}' -}
      end
      
      # extracts the title from pdf meta data
      # needs pdfinfo
      # returns the title or nil if no title was found
      def get_title(path_to_tempfile)
        %x{#{@pdfinfo} -enc UTF-8 '#{path_to_tempfile}'} =~ /title:\s+(.*)$/i ? $1.strip : nil
      rescue
      end
    end

  end
end
