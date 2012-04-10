module SpamFilter
  module Config
    
    # default folder locations for learning emails
    DEFAULT_SPAM_CORPUS = 'corpus/spam'
    DEFAULT_HAM_CORPUS  = 'corpus/ham'

    # default folder locations for testing emails
    DEFAULT_SPAM_TEST   = 'corpus/test_spam'
    DEFAULT_HAM_TEST    = 'corpus/test_ham'

    DEFAULT_TOP_TOKENS_LIST_SIZE = 27
    DEFAULT_SPAM_THRESHOLD       = 0.9
    DEFAULT_HAM_TOKEN_MULTIPLIER = 1
    DEFAULT_SPAMICITIES_FILE     = false

    REGEXP = { :html_comment => /<!--.*?-->/,
               :core_token   => /[A-Za-z0-9'$!-]+/,
               :token_pair   => /([A-Za-z0-9'$!-]+)[^A-Za-z0-9'$!-]+?(?=([A-Za-z0-9'$!-]+))/, 
               # :price_range  => /(\$?\d+(?:\d*[,.])+\d+)-(\$?\d+(?:\d*[,.])+\d+)/,
               :ip_url       => /(?:\d+[.,])*\d+/ } 
               # :breakdown    => /([A-Za-z0-9$]+)[.,-](?=((?:[A-Za-z0-9$]+[.,-])*[A-Za-z0-9$]+))/,

    VALID_DIRECTORY_OPTIONS = [
      :spam_corpus,
      :ham_corpus,
      :spam_test,
      :ham_test,
    ]

    VALID_OPTIONS_KEYS = [
      :top_tokens_list_size,
      :spam_threshold,
      :ham_token_multiplier,
      :spamicities_file
    ]

    attr_reader *VALID_DIRECTORY_OPTIONS
    attr_accessor *VALID_OPTIONS_KEYS

    def method_missing(method, *args, &block)
      method_name = method.to_s[0...-1].to_sym
      if VALID_DIRECTORY_OPTIONS.include?(method_name)
        mod_arg = Dir["#{args[0]}/*"]
        instance_variable_set("@#{method_name}", mod_arg)
      end
    end
    
    def self.extended(base)
      base.reset
    end

    def configure
      yield self
      self
    end

    def reset
      self.spam_corpus          = DEFAULT_SPAM_CORPUS
      self.ham_corpus           = DEFAULT_HAM_CORPUS
      self.spam_test            = DEFAULT_SPAM_TEST
      self.ham_test             = DEFAULT_HAM_TEST
      self.top_tokens_list_size = DEFAULT_TOP_TOKENS_LIST_SIZE
      self.spam_threshold       = DEFAULT_SPAM_THRESHOLD
      self.ham_token_multiplier = DEFAULT_HAM_TOKEN_MULTIPLIER
      self.spamicities_file     = DEFAULT_SPAMICITIES_FILE
    end
    
    def load_token_spamicities
      print 'Loading token spamicities...'
      spamicities = begin
        YAML.load(File.open(spamicities_file))
      rescue ArgumentError => e
        puts "Could not parse YAML: #{e.message}"
      end
      puts 'done.'
      spamicities
    end
  end
end
