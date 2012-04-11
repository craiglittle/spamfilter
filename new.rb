class SpamFilter
  MIN_SPAM_SCORE  = 0.6
  ASSUMED_PROB    = 0.5
  PREDICT_WEIGHT  = 1
  REGEXP = { :html_comment => /<!--.*?-->/,
             :core_token   => /[A-Za-z0-9'$!-]+/,
             :ip           => /(?:\d+[.,])*\d+/,
             :token_pair   => /([A-Za-z0-9'$!-]+)[^A-Za-z0-9'$!-]+?(?=([A-Za-z0-9'$!-]+))/,
             :all_digits   => /^\d+\s|\s\d+$|^\d+$/ } 

  def initialize
    @token_data = {}
    @msg_count  = { :spam => 0, :ham => 0 }
  end

  def database
    [@token_data, @msg_count]
  end

  def classify(text)
    tokens    = extract_tokens(text)
    msg_score = score(tokens) 

    classification(msg_score)
  end

  def classification(score)
    score > MIN_SPAM_SCORE ? :spam : :ham
  end

  def read(filename)
    File.read(filename)
  end

  def analyze(text, type)
    tokens = extract_tokens(text)
    tokens.each do |token| 
      next if token.match(REGEXP[:all_digits])
      @token_data[token] = { :spam => 0, :ham => 0 } if @token_data[token].nil?
      @token_data[token][type] += 1
    end
    @msg_count[type] += 1 
  end

  def extract_tokens(text)
    cleaned_text = text.gsub(REGEXP[:html_comment], '')
    tokens       = [:core_token, :ip].inject([]) { |tokens, regexp| tokens += cleaned_text.scan(REGEXP[regexp]).flatten }
    pairs        = cleaned_text.scan(REGEXP[:token_pair])
    token_pairs  = pairs.map { |pair| pair.join(' ') }

    (tokens + token_pairs).uniq
  end

  def spam_probability(token)
    # return 0.5 if untrained?(token)
    spam_count   = @token_data[token][:spam]
    ham_count    = @token_data[token][:ham]
    data_points  = spam_count + ham_count

    spam_freq  = spam_count / [1, @msg_count[:spam]].max.to_f
    ham_freq   = ham_count / [1, @msg_count[:ham]].max.to_f
    basic_prob = spam_freq / (spam_freq + ham_freq)

    ((PREDICT_WEIGHT * ASSUMED_PROB + data_points * basic_prob) / (PREDICT_WEIGHT + data_points)).round(4)
  end

  def score(tokens)
    spam_probs = []
    ham_probs = []
    prob_count = 0

    tokens.each do |token|
      unless untrained?(token) # && !interesting?(token)
        spam_prob = spam_probability(token)
        spam_probs << spam_prob
        ham_probs << 1.0 - spam_prob
        prob_count += 1
      end
    end

    h = 1 - fisher(spam_probs, prob_count)
    s = 1 - fisher(ham_probs, prob_count)

    ((s + (1 - h)) / 2.0).round(4)
  end

  def fisher(probs, prob_count)
    chi = -2 * probs.inject(0) { |total, prob| total += Math.log(prob) }
    df = 2 * prob_count 
    inverse_chi_square(chi, df)
  end

  def inverse_chi_square(chi, df)
    m  = chi / 2.0
    sum = term = Math.exp(-m)
    (1..df/2).each do |i|
      term *= m / i
      sum += term
    end
    [1.0, sum].min
  end

  # def interesting?(token)
  #   abs_spamicity = (0.5 - @token_data[token][:spam_prob]).abs
  #   abs_spamicity > 0.4
  # end

  def untrained?(token)
    !@token_data[token]
  end
end
