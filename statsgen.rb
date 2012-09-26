load('Dicebox.rb')

def gen_histogram_file(modifiers)
  size = 100000
  roller = Dicebox.new
  file_name = "roll_hist"
  file_name += "_d_" + modifiers[:sidesPerDie].to_s
  file_name += "_e_" + modifiers[:explodeOn].to_s
  file_name += "_rr_" + modifiers[:rerollBelow].to_s
  new_file = File.new file_name, "wb"
  roll_hash = {}
  (1..10).each do |r|
    roll_hash[r] = {}
    (1..r).each do |k|
      vals = [ 0 ]
      #puts "starting:#{r}k#{k}"
      (1..size).each do |count|
        index = roller.RollKeep(r,k,modifiers)[:total]
        vals.fill(0, vals.length, index-vals.length + 1) unless vals.length > index        
        vals[index] += 1
      end
      roll_hash[r][k] = vals
      #puts vals.join ":"
    end  
  end
  #puts roll_hash[6][1]
  new_file.write Marshal.dump(roll_hash)
  new_file.close
end

gen_histogram_file({sidesPerDie:10, explodeOn:10, rerollBelow:0}) #non emphasis attack rolls
gen_histogram_file({sidesPerDie:10, explodeOn:9, rerollBelow:0}) #weapon damage with exploding 9's
gen_histogram_file({sidesPerDie:10, explodeOn:10, rerollBelow:2}) #emphasis