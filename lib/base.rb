module SpamFilter
  extend Config
  class << self

    def run
      token_spamicities = spamicities_file ? load_token_spamicities : calculate_spamicities
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

    def parse_corpus(corpus_type, token_map, email_count)
      corpus = (corpus_type == :spam ? spam_corpus : ham_corpus)
      corpus.each do |email| 
        email_count[corpus_type] += 1
        tokens = tokenize_email(email)
        record_tokens(tokens, corpus_type, token_map)
      end
    end
    
    def tokenize_email(email)
      email_text = File.read(email).encode('UTF-16BE', 
                                           :invalid => :replace, 
                                           :replace => '?').encode('UTF-8')
      tokenize_text(email_text)
    end

    def tokenize_text(text)
      cleaned_text = text.gsub(REGEXP[:html_comment], '')
      tokens = [:ip_url, :core_token].inject([]) { |tokens, regexp| tokens += cleaned_text.scan(REGEXP[regexp]).flatten }
      token_pairs = cleaned_text.scan(REGEXP[:token_pair])
      tokens += token_pairs.map { |pair| pair.join(' ') }
      tokens.uniq
    end

    def record_tokens(tokens, corpus_type, token_map)
      tokens.each do |token| 
        next if token.match(/^\d+\s|\s\d+$|^\d+$/) # ignore pure numbers
        token_map[token] = { :spam => 0, :ham => 0 } if token_map[token].nil?
        token_map[token][corpus_type] += 1
      end
    end

    def calculate_spamicities
      token_map   = {}
      email_count = { :spam => 0, :ham => 0 }
      parse_corpus(:spam, token_map, email_count)
      puts 'Done with spam.'
      parse_corpus(:ham, token_map, email_count)
      puts 'Done with ham.'

      token_map.each do |token, _|
        spam_count = token_map[token][:spam]
        ham_count  = token_map[token][:ham]
        data_points  = spam_count + ham_count

        if data_points < 5
          token_map.delete(token)
          next
        end

        spam_freq  = spam_count / [1, email_count[:spam]].max.to_f
        ham_freq   = ham_count / [1, email_count[:ham]].max.to_f
        basic_prob = spam_freq / (spam_freq + ham_freq)

        # frequency adjustment
        assumed_prob = 0.5
        strength     = 1
        spamicity = (strength * assumed_prob + data_points * basic_prob) / (strength + data_points)

        token_map[token][:spamicity] = spamicity
      end
      
      File.open('spamicities.yml', 'w') { |f| f.write(token_map.to_yaml) }
      token_map
    end

    def score_emails(corpus_type, token_spamicities)
      print "Testing #{corpus_type.to_s} emails..."
      emails = corpus_type == :spam ? spam_test : ham_test
      test_output = emails.inject([]) { |output, email| output << test_single_email(email, corpus_type, token_spamicities) }
      puts 'done.'
      test_output
    end
    
    def score_email(email, corpus_type, token_spamicities)
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

    def score(tokens, token_spamicities)
      spam_probs = []
      ham_probs  = []
      prob_count = 0

      tokens.each do |token|
        if interesting?(token, token_spamicities)
          spam_prob = token_spamicities[token][:spamicity]
          spam_probs << spam_prob
          ham_probs << 1.0 - spam_prob
          prob_count += 1
        end
      end

      h = 1 - fisher(spam_probs, prob_count)
      s = 1 - fisher(ham_probs, prob_count)

      (s + (1 - h)) / 2.0
    end
    
    def interesting?(token, token_spamicities)
      abs_spamicity = (0.5 - token_spamicities[token][:spamicity]).abs
      abs_spamicity > 0.4
    end

    def fisher(probs, prob_count)
      chi = -2 * probs.inject(0) { |total, prob| total += prob.log }
      df  = 2 * prob_count 
      inverse_chi_square(chi, df)
    end

    def inverse_chi_square(chi, df)
      m = chi / 2.0
      sum = term = math.exp(-m)
      (1..df/2).each do |i|
        term *= m / i
        sum += term
      end
      [1.0, sum].min
    end
  end
end
