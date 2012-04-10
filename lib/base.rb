module SpamFilter
  extend Config
  class << self

    def run
      token_spamicities = spamicities_file ? load_token_spamicities : calculate_token_spamicities
      spam_results = test_emails(:spam, token_spamicities)
      ham_results  = test_emails(:ham, token_spamicities)

      report_results(spam_results, ham_results)
    end
    
    def report_results(spam_results, ham_results)
      missed_spam = error_count(spam_results)
      spam_email_count = spam_results.size
      filter_rate = (spam_email_count - missed_spam) / spam_results.size.to_f

      false_positives = error_count(ham_results)
      ham_email_count   = ham_results.size
      false_positive_rate = false_positives / ham_email_count.to_f

      puts "\n\tTest Results"
      puts "\t" << '*' * 10
      puts "\tTest email count: \t#{spam_email_count + ham_email_count}"
      puts "\t" << '*' * 5
      puts "\tSpam email count: \t#{spam_email_count}"
      puts "\tMissed spam: \t\t#{missed_spam}"
      puts "\tFilter rate: \t\t#{(filter_rate * 100).round(2)}%"
      puts "\t" << '*' * 5
      puts "\tHam email count: \t#{ham_email_count}"
      puts "\tFalse positives: \t#{false_positives}"
      puts "\tFalse positive rate: \t#{(false_positive_rate * 100).round(2)}%"
      puts "\t" << '*' * 10 << "\n\n"
    end

    def error_count(results)
      results.select { |email| email[:accurate?] == false }.size
    end

    def parse_corpus(emails)
      emails.inject({}) { |tokens, email| tokenize_email(email, tokens); tokens }
    end
    
    def tokenize_email(email, tokens = {})
      email_text = File.read(email).encode('UTF-16BE', 
                                           :invalid => :replace, 
                                           :replace => '?').encode('UTF-8')
      raw_tokens = tokenize_text(email_text)
      hashify_tokens(raw_tokens, tokens)
    end

    def tokenize_text(text)
      cleaned_text = text.gsub(REGEXP[:html_comment], '')
      tokens = [:ip_url, :core_token].inject([]) { |tokens, regexp| tokens += cleaned_text.scan(REGEXP[regexp]).flatten }
      token_pairs = cleaned_text.scan(REGEXP[:token_pair])
      str_pairs = token_pairs.map { |pair| pair.join(' ') }
      tokens += str_pairs
    end

    def hashify_tokens(raw_tokens, tokens = {})
      raw_tokens.inject(tokens) do |tokens, token| 
        next tokens if token.match(/^\d+\s|\s\d+$|^\d+$/) # ignore pure numbers
        tokens[token] ? tokens[token] += 1 : tokens[token] = 1; tokens
      end
    end

    def calculate_token_spamicities
      puts 'Calculating token spamicities...'

      spam_tokens      = parse_corpus(spam_corpus)
      spam_email_count = spam_corpus.length
      puts 'Done with spam.'
      ham_tokens       = parse_corpus(ham_corpus)
      ham_email_count  = ham_corpus.length
      puts 'Done with ham.'

      token_spamicities = {}
      unique_tokens = (spam_tokens.keys + ham_tokens.keys).uniq

      unique_tokens.each do |token|
        spam_token_count = spam_tokens[token] || 0
        ham_token_count  = (ham_tokens[token] || 0) * ham_token_multiplier

        unless spam_token_count + ham_token_count < 10
          spam_pct      = [1.0, spam_token_count / spam_email_count.to_f].min
          ham_pct       = [1.0, ham_token_count / ham_email_count.to_f].min
          bayes_pct     = (spam_pct / (spam_pct + ham_pct)).round(2)
          adj_bayes_pct = [0.01, [0.99, bayes_pct].min].max

          token_spamicities[token] = adj_bayes_pct
        end
      end
      
      File.open('spamicities.yml', 'w') { |f| f.write(token_spamicities.to_yaml) }
      token_spamicities
    end
    
    def test_emails(corpus_type, token_spamicities)
      print "Testing #{corpus_type.to_s} emails..."
      emails = corpus_type == :spam ? spam_test : ham_test
      test_output = emails.inject([]) { |output, email| output << test_single_email(email, corpus_type, token_spamicities) }
      puts 'done.'
      test_output
    end
    
    def test_single_email(email, corpus_type, token_spamicities)
      tokens = tokenize_email(email)
      tokens.each do |k, v| 
        spamicity = token_spamicities[k] || 0.5
        tokens[k] = { :count         => v,
                      :spamicity     => spamicity,
                      :abs_spamicity => (spamicity - 0.5).abs }
      end

      sorted_tokens = tokens.sort_by{ |_, values| values[:abs_spamicity] }
      top_tokens = []

      while top_tokens.size < top_tokens_list_size
        top_token = sorted_tokens.pop
        repeat = (top_tokens.size == top_tokens_list_size - 1 ? 1 : [2, top_token[1][:count]].min)
        repeat.times { top_tokens << top_token }
      end
      top_tokens = top_tokens.inject({}) { |hash, token| hash[token[0]] = token[1]; hash }

      n = top_tokens.inject(0) { |result, token| result + (Math.log(1 - token[1][:spamicity]) - Math.log(token[1][:spamicity])) }
      email_spamicity = (1 / (1 + Math.exp(n)))
      verdict = email_spamicity >= spam_threshold ? :spam : :ham 

      # { :path => email, :spamicity => email_spamicity, :top_tokens => top_tokens, :verdict => verdict, :accurate? => verdict == corpus_type }
      { :accurate? => verdict == corpus_type }
    end
  end
end
