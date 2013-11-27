class SearchIndex
  attr_accessor :use_tf_idf

  def initialize(connection, use_tf_idf = true, k = 2.0, b = 0.75)
    @connection = connection
    @use_tf_idf = use_tf_idf

    @k = k
    @b = b

    self.rebuild!
  end

  def rebuild!(use_tf_idf = nil)
    @use_tf_idf = use_tf_idf unless use_tf_idf.nil?

    use_tf_idf ||= @use_tf_idf

    @idfs = {}

    @documents = @connection.exec('SELECT * FROM documents;').map do |document_result|
      document_hash = {
          :id => document_result['id'],
          :text => document_result['text'],
          :words => words(document_result['text'])
      }

      document_hash[:normalized_text] = " #{ document_hash[:words].join(' ') } "

      document_hash
    end

    @avg_d = @documents.map{ |d| d[:words].size }.sum.to_f / @documents.size unless use_tf_idf

    @documents.each_with_index do |document_hash, i|
      document_hash[:index] = {}

      document_hash[:words].uniq.each do |word|
        document_hash[:index][word] = (use_tf_idf ? tf_idf(word, i) : bm25(word, i))
      end
    end
  end

  def words(text)
    text.downcase.gsub(/[^a-z]/, ' ').squish.split(' ')
  end

  def tf_idf(word, document_index)
    [0, tf(word, document_index) * idf(word)].max
  end

  def bm25(word, document_index)
    idf(word) * ((tf(word, document_index) * @k + 1) / (tf(word, document_index) + @k * (1 - @b + @b * (@documents.size.to_f / @avg_d))))
  end


  def tf(word, document_index)
    @documents[document_index][:normalized_text].scan(" #{ word } ").size.to_f / @documents[document_index][:words].size
  end

  def idf(word)
    @idfs[word] ||= Math.log(@documents.size.to_f / @documents.select{ |d| d[:normalized_text].include? " #{ word } " }.size)
  end

  def search(query)
    query_words = words(query)

    @documents.each do |document_hash|
      document_hash[:score] = query_words.map do |query_word|
        document_hash[:index][query_word].to_f
      end.sum
    end

    @documents.sort { |a, b| b[:score] <=> a[:score] }.select{ |d| d[:score] > 0 }
  end
end
