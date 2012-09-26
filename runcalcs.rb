#Helper for creatings CSV file output.
class CsvWriter
  def initialize file, columns, labels
    @current_values = {}
    @columns = columns
    @file = file
    
    @file.puts @columns.join ","    
  end
  
  def update new_vals
    new_vals.each{ |key, value| @current_values[key] = value}
  end
  
  def write new_vals=nil
    update new_vals unless new_vals.nil?
    @file.puts @columns.map{|x| @current_values[x]}.join ","
  end
  
  def close
    @file.close
  end
end

class FeintCalculator
  def initialize
    @scale = 100000.0
    @base_rolls = Marshal.load(File.binread("roll_hist_d_10_e_10_rr_0"))
    @mastery_rolls = Marshal.load(File.binread("roll_hist_d_10_e_9_rr_0"))
    @emphasis_rolls = Marshal.load(File.binread("roll_hist_d_10_e_10_rr_2"))
    @outfile = File.open("results.txt", "w")
    
    column_labels = ["Attack Rolled", "Attack Kept", "Damage Rolled", "Damage Kept", "Damage Explodes On", "School Rank", "Feint Raises", "Damage Raises", "TNTBH", "Expected Damage"]
    columns = [:ar,:ak,:dr,:dk,:deo,:sr,:fraise,:draise,:tn,:ed]
    csvfile = File.open("results.csv", "w")    
    @csv_writer = CsvWriter.new(csvfile, columns, column_labels)            
  end  

  #return the probability of hitting a given TN for a histogram of data.
  def hit_chance hist, tn    
    sum = 0
    
    #are we trying to hit a TN higher than any of our dice rolled?
    if (tn > (hist.length-1)) then 
      return 0
    end    
    
    #for each entry higher than or equal to our TN (every hit) add together the number of successes
    (tn..hist.length-1).each do |index| 
      sum += hist[index]
    end
    
    return sum/@scale    
  end
  
  #return the expected damage based on the average damage the attack will do, 
  #the attack roll histogram, the TN of the target (post raises)
  #a boolean if they are feinting or not and school rank if feinting
  def expected_damage roll_hist, damage, tn, feint=false, sr = 0
    sum = 0.0
    
    if (tn > (roll_hist.length-1)) then
      return 0.0
    end    
    
    (tn..roll_hist.length-1).each do |index|
      #determine feint damage if needed
      offset = feint ? [(index-tn)/2, sr*5].min : 0
      #cumulative sum of the odds of exactly rolling a given result times the damage dealt at that result.
      sum += (roll_hist[index]/@scale)*(damage+offset)
    end
    
    return sum
  end  
  
  #populate all the outputs with all permutations for a given number of rolled and kept dice
  def calc_attack_roll roll, keep    
    @outfile.write "\n\n\n"
    @outfile.puts "-#{roll}k#{keep}- Attack Roll"
    
    roll_hist = @emphasis_rolls[roll][keep]
    
    #Step through our target TN ranges by 5
    (5..50).step(5).each do |tntbh|    
      @outfile.puts "\nBase Chance to hit TN#{tntbh}: #{(100*(hit_chance roll_hist, tntbh)).round(2)}%"    
      @csv_writer.update({ar:roll, ak:keep, sr:0, tn:tntbh})
      
      (1..10).each do |d_r|   
        (1..d_r).each do |d_k|        
          @outfile.puts "*#{d_r}k#{d_k}*"
          calc_damage d_r, d_k, roll_hist, tntbh          
        end
      end
    end
  end  
  
  #Helper, performs damage calcs once for exploding on 10 damage, and again for exploding on 9's
  def calc_damage d_r, d_k, roll_hist, tn
    calc_damage_data d_r,d_k, roll_hist, tn, 10, @base_rolls
    calc_damage_data d_r,d_k, roll_hist, tn, 9, @mastery_rolls
  end
  
  def calc_damage_data d_r, d_k, roll_hist, tn, explode, rolls   
    
    @csv_writer.update({dr:d_r, dk:d_k, deo:explode, fraise:0, draise:0, sr:0})
    #determine our base damage that we'll do with this roll to figure out all of our expected damages from
    base_dam = rolls[d_r][d_k].each_with_index.map{ |x,i| i*x}.reduce(:+)/@scale
    base_expected_dam = expected_damage roll_hist, base_dam, tn
    write_damage_header explode, base_expected_dam    
    @csv_writer.write({ed:base_expected_dam})        
    
    #Feint maneuver at ranks 1-5
    calc_feint_damage base_expected_dam, roll_hist, base_dam, tn, explode, 2
    #Feint maneuver as acorpion for rank 1-5.
    calc_feint_damage base_expected_dam, roll_hist, base_dam, tn, explode, 1
    
     
    @csv_writer.update({fraise:0, draise:0, sr:0})
    #1 to 4 damage raises, need to abstract rollover code and this whole sub block
    (1..4).each do |dam_raises|
      new_roll = [d_r+dam_raises, 10].min
      new_keep = d_r+dam_raises > 10 ? d_k+(d_r+dam_raises-10)/2 : d_k
      offset = 0
      if new_keep > 10 then
        offset = (new_keep-10)*2
        new_keep = 10
      end      
      base_dam = rolls[new_roll][new_keep].each_with_index.map{ |x,i| i*x}.reduce(:+)/@scale + offset
      expected_dam = expected_damage roll_hist, base_dam, tn+5*dam_raises
      next unless base_expected_dam < expected_dam
      @outfile.puts "exploding on #{explode} called damage raises #{dam_raises} expected damage:#{expected_dam.round(1)}"
      @csv_writer.write({ed:expected_dam, draise:dam_raises})
    end    
    
  end
  
  def calc_feint_damage base_expected_dam, roll_hist, base_dam, tn, explode, raises 
    (1..5).each do |school_rank|
        expected_dam = expected_damage roll_hist, base_dam, tn+5*raises, true, school_rank
        next unless base_expected_dam < expected_dam
        @outfile.puts "exploding on #{explode} feinting for #{raises} raise(s) at rank #{school_rank} expected damage:#{expected_dam.round(1)}"
        @csv_writer.write({ed:expected_dam, fraise:raises, sr:school_rank})        
    end
  end
  
  def write_damage_header explode, dam    
    @outfile.puts "exploding on #{explode} base damage:#{dam.round(1)}"
  end
  
end

calc = FeintCalculator.new
(1..10).each do |r|   
  (1..r).each do |k|
    calc.calc_attack_roll r, k
  end 
end