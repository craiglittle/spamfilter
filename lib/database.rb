class SpamFilter

  def self.clear_database
    begin
      filename = File.read('.spamfilter').strip
      File.delete(database_filename)
    rescue
      nil
    end
  end

  def save
    File.open(@database_filename, 'w') { |f| f.write(Marshal.dump(@database)) }
  end

  def read(file)
    File.read(file).encode('UTF-16BE', 
                            :invalid => :replace, 
                            :replace => '?').encode('UTF-8')
  end

  def empty_database
    { :token_data => {},
      :msg_count  => { :spam => 0, :ham => 0 } }
  end

  def load_from_database
    begin
      Marshal.load(File.open(@database_filename))
    rescue 
      nil
    end
  end
end
