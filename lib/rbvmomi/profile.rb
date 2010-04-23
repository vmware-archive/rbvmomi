module Kernel
  PROFILE_TIMES = Hash.new 0.0

  def profile sym, &b
    start_time = Time.now
    ret = b.call
    elapsed = Time.now - start_time
    PROFILE_TIMES[sym] += elapsed
    puts "#{sym} #{elapsed}s" if $profile
    ret
  end

  def dump_profile
    PROFILE_TIMES.sort_by { |k,v| -v }.each do |sym,total|
      puts "#{sym} #{total}"
    end
  end
end

at_exit { dump_profile if $profile }
