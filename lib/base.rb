class SpamFilter
  MIN_SPAM_SCORE = 0.9
  ASSUMED_PROB   = 0.5
  PREDICT_WEIGHT = 1
  REGEXP = { :html_comment => /<!--.*?-->/,
             :subject      => /Subject:([\s\w]+)\n/,
             :core_token   => /[A-Za-z0-9'$!-]+/,  
             :ip           => /(?:\d+[.,])*\d+/,
             :token_pair   => /([A-Za-z0-9'$!-]+)[^A-Za-z0-9'$!-]+?(?=([A-Za-z0-9'$!-]+))/,
             :all_digits   => /^\d+\s|\s\d+$|^\d+$/ } 

  def initialize
    @database_filename = File.read('.spamfilter').strip || '.spam_probabilities'
    @database = load_from_database || empty_database
    @token_data = @database[:token_data]
    @msg_count  = @database[:msg_count]
  end

  def train(text, type)
    tokens = extract_tokens(text)
    tokens.each do |token| 
      next if token.match(REGEXP[:all_digits])
      @token_data[token] = { :spam => 0, :ham => 0 } if @token_data[token].nil?
      @token_data[token][type] += 1
    end
    @msg_count[type] += 1 
  end

  def classify(text)
    tokens = extract_tokens(text)
    score  = score(tokens) 

    score > MIN_SPAM_SCORE ? :spam : :ham
  end

  # Alphanumeric characters, hyphens, dollar signs, apostrophes, and
  # exclamation points are constituent characters. Everything else is
  # whitespace. Tokens consisting of all digits are ignored except for those
  # containing periods and commas to pick up prices and ip addresses. Token
  # pairs using the same rules are also included.
  def extract_tokens(text)
    tokens = []

    cleaned_text = text.gsub(REGEXP[:html_comment], '')
    subject      = cleaned_text.scan(REGEXP[:subject])
    tokens       += subject.flatten[0].strip.split.map { |token| "subject*#{token}" } unless subject.empty?

    [:core_token, :ip].inject([]) { |tokens, regexp| tokens += cleaned_text.scan(REGEXP[regexp]).flatten }.uniq

    pairs = cleaned_text.scan(REGEXP[:token_pair])
    tokens += pairs.map { |pair| pair.join(' ') }

    tokens.map { |token| token.downcase}.uniq
  end

  # Spam probability corrected for token rarity. Higher(lower)
  # probabilities, and therefore more prominence in the overall message
  # spaminess calculation, assigned to tokens which occur more frequently
  # in the training corpus. This is done by assuming a beta distribution for the
  # spamminess of a message that contains a given token. Rare tokens have more
  # weight placed on a neutral score of 0.5.
  def spam_probability(token)
    spam_count  = @token_data[token][:spam]
    ham_count   = @token_data[token][:ham]
    data_points = spam_count + ham_count

    spam_freq  = spam_count / [1, @msg_count[:spam]].max.to_f
    ham_freq   = ham_count / [1, @msg_count[:ham]].max.to_f
    basic_prob = spam_freq / (spam_freq + ham_freq)

    ((PREDICT_WEIGHT * ASSUMED_PROB + data_points * basic_prob) / (PREDICT_WEIGHT + data_points)).round(4)
  end

  # Computes the overall 'spamminess' of the given set of tokens by combining
  # the individual token spam probabilities using the Fisher method. Tokens
  # that do not meet a given level of (non)spamminess are excluded. Fisher
  # spamminess and hamminess probabilities are averaged to get the overall
  # spamminess score.
  def score(tokens)
    spam_probs, ham_probs = [], []

    tokens.each do |token|
      if trained?(token)
        @token_data[token][:spam_prob] ||= spam_probability(token)
        next unless interesting?(@token_data[token][:spam_prob])
        spam_probs << @token_data[token][:spam_prob]
        ham_probs << 1.0 - @token_data[token][:spam_prob]
      end
    end

    h = 1 - fisher(spam_probs)
    s = 1 - fisher(ham_probs)

    ((s + (1 - h)) / 2.0).round(4)
  end

  # Implementation of the Fisher method for combining event probabilities.
  # Assumes that the probability that certain words appear together are not
  # independent--certain tokens are likely to appear together, while others
  # never do. Relies on refuting a null hypothesis that a message is just
  # a random collection of tokens through use of the inverse chi square 
  # distribution.
  def fisher(probs)
    chi = -2 * probs.inject(0) { |total, prob| total += Math.log(prob) }
    df = 2 * probs.size
    inverse_chi_square(chi, df)
  end

  # Implemention of inverse chi square distribution function. A sufficiently
  # low return value from this function disproves the null hypothesis that the
  # tokens are random and the hypothesis (either ham or spam) is confirmed.
  def inverse_chi_square(chi, df)
    m  = chi / 2.0
    sum = term = Math.exp(-m)
    (1..df/2).each do |i|
      term *= m / i
      sum += term
    end
    [1.0, sum].min
  end

  def interesting?(spam_prob)
    (0.5 - spam_prob).abs > 0.4
  end

  def trained?(token)
    @token_data[token]
  end
end
