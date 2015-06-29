#!/usr/bin/ruby

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

    def setup

    end

    def add(data)
    end

    def similarity(s1, s2)
    end
  end

  class Estimote
    include ::Storage::RubyList

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
  sim = inter.to_f / union(datum, s1, s2)
  est_sim = store.similarity(s1, s2)
  est_inter = store.similarity(s1, s2) * union(datum, s1, s2)

  puts "inter    : #{inter}"
  puts "union    : #{union(datum, s1, s2)}"
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

print(datum, store, :s1, :s2)
print(datum, store, :s1, :s3)
print(datum, store, :s1, :s4)
print(datum, store, :s2, :s3)
print(datum, store, :s2, :s4)
print(datum, store, :s3, :s4)
