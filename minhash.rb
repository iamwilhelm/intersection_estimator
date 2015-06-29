#!/usr/bin/ruby

require 'redis'
require 'murmurhash3'
require 'pp'

datum = [
  { s1: 1, s2: 0, s3: 0, s4: 0 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
  { s1: 0, s2: 1, s3: 1, s4: 1 },
  { s1: 1, s2: 0, s3: 1, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
  { s1: 1, s2: 1, s3: 0, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
  { s1: 0, s2: 1, s3: 0, s4: 1 },
  { s1: 1, s2: 0, s3: 1, s4: 1 },
  { s1: 0, s2: 0, s3: 0, s4: 0 },
  { s1: 1, s2: 1, s3: 0, s4: 1 },
  { s1: 0, s2: 1, s3: 1, s4: 1 },
  { s1: 0, s2: 1, s3: 0, s4: 0 },
  { s1: 1, s2: 0, s3: 0, s4: 1 },
  { s1: 0, s2: 1, s3: 1, s4: 0 },
  { s1: 1, s2: 0, s3: 0, s4: 1 },
  { s1: 0, s2: 1, s3: 1, s4: 0 },
  { s1: 1, s2: 1, s3: 0, s4: 1 },
  { s1: 1, s2: 0, s3: 1, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
  { s1: 1, s2: 1, s3: 0, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
  { s1: 0, s2: 1, s3: 0, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 1 },
  { s1: 0, s2: 0, s3: 0, s4: 1 },
  { s1: 1, s2: 1, s3: 0, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
  { s1: 0, s2: 1, s3: 0, s4: 1 },
  { s1: 1, s2: 0, s3: 0, s4: 1 },
  { s1: 0, s2: 0, s3: 1, s4: 0 },
]
pp datum
puts

module Storage

  module RubyList

    def setup(keys)
      @minhash = (0...@hashes.length).map do |i|
        Hash[*keys.map { |k| [k, Float::INFINITY] }.flatten]
      end
    end

    def add(data)
      hash_val = @hashes.map { |hash| hash.call(@data_count) }
      @data_count += 1

      #puts hash_val.to_s

      @minhash = @minhash.each_with_index.map do |minrow, j|
        Hash[*minrow.map do |set, minvalue|
          [set, data[set] == 1 && hash_val[j] < minvalue ? hash_val[j] : minvalue]
        end.flatten]
      end
    end

    def similarity(s1, s2)
      y = @minhash.inject(0) { |t, minrow| t += (minrow[s1] == minrow[s2] ? 1 : 0) }
      k = @minhash.length.to_f
      return y / k
    end
  end

  module Redis

    def setup(sets)
      @redis = ::Redis.new

      sets.each do |set|
        @redis.del "hmhll:minhash:#{set}"
        @redis.hmset "hmhll:minhash:#{set}", *(0...@hashes.length).map { |i| [i, 2**64] }.flatten
      end
    end

    def add(data)
      hash_val = @hashes.map { |hash| hash.call(@data_count) }
      @data_count += 1

      data.keys.each do |set|
        next unless data[set] == 1
        min_hashes = @redis.hgetall("hmhll:minhash:#{set}").map do |hash_num, minvalue|
          [hash_num, hash_val[hash_num.to_i] < minvalue.to_i ? hash_val[hash_num.to_i] : minvalue ]
        end
        @redis.hmset "hmhll:minhash:#{set}", *min_hashes.flatten
      end
    end

    def similarity(s1, s2)
      s1_vals = @redis.hvals("hmhll:minhash:#{s1}").map(&:to_i)
      s2_vals = @redis.hvals("hmhll:minhash:#{s2}").map(&:to_i)
      #puts s1_vals.to_s
      #puts s2_vals.to_s

      y = s1_vals.zip(s2_vals).inject(0) { |t, e| t += (e[0] == e[1] ? 1 : 0) }
      k = s1_vals.length
      return y.to_f / k
    end
  end

  class Estimote
    include ::Storage::Redis

    def initialize(keys, num_hashes = 300)
      @data_count = 0

      @hashes = (0..num_hashes).map do |a|
        proc { |x| MurmurHash3::V32.int64_hash(x, a) }
      end

      # build minhash data structure
      setup(keys)
    end
  end

end

def union(datum, s1, s2)
  a = datum.map { |e| e[s1] }
  b = datum.map { |e| e[s2] }
  a.zip(b).map { |e| e[0] | e[1] }.inject(0) { |t, e| t += e }
end

def intersection(datum, s1, s2)
  a = datum.map { |e| e[s1] }
  b = datum.map { |e| e[s2] }
  a.zip(b).map { |e| e[0] & e[1] }.inject(0) { |t, e| t += e }
end

def print(datum, store, s1, s2)
  puts "#{s1} : #{s2}"

  inter = intersection(datum, s1, s2)
  union = union(datum, s1, s2)
  sim = inter.to_f / union.to_f
  est_sim = store.similarity(s1, s2)
  est_inter = est_sim * union

  puts "inter    : #{inter}"
  puts "union    : #{union}"
  puts "sim      : #{sim}"
  puts "est sim  : #{est_sim}"
  puts "est inter: #{est_inter}"

  puts "sim squared err rate   : #{((est_sim - sim) / sim) * 100}"
  puts "inter squared err rate : #{((est_inter - inter) / inter) * 100}"
  puts
end

store = Storage::Estimote.new([:s1, :s2, :s3, :s4])

datum.each do |data|
  store.add(data)
end

#print(datum, store, :s1, :s2)
print(datum, store, :s1, :s3)
print(datum, store, :s1, :s4)
print(datum, store, :s2, :s3)
print(datum, store, :s2, :s4)
print(datum, store, :s3, :s4)
