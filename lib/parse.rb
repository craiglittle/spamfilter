class SpamFilter
  def process_messages(path, type)
    counter = 0
    Dir[path].each do |message|
      text = read(message)
      train(text, type)
      counter += 1
    end
    counter
  end
end
