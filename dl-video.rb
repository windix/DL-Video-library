#!/usr/bin/ruby -w

# == Synopsis
#
# Command line interface for DL-Video (http://en.dl-video.net)
# 
# == Usage
# 
# ruby dl-video.rb <video_url> [<option>]
# 
# Option: 
#   -c Download via curl (default)
#   -m Manual download via curl (generate curl script)
#   -r Download directly via ruby
# 
# == Author
# 
# Windix Feng, windix@gmail.com
# 
# == Copyright
#
# GPL

require 'net/http'
require 'uri'
require 'open-uri'
require 'cgi'
require 'rdoc/usage'

class DLVideo
  attr_accessor :url, :filename

  def initialize(url, filename)
    @url, @filename = url, filename

    @@user_agent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_7; en-us) AppleWebKit/525.28.3 (KHTML, like Gecko) Version/3.2.3 Safari/525.28.3"
  end

  # Initialize DLVideo from URL, return a list of videos
  def self.from_url(url)
    res = Net::HTTP.post_form(URI.parse('http://en.dl-video.net/'),
                              {'sdurl' => url, 'sm' => '1', 'x'=>'QFtoAXCMlQU'})
    @html = res.body

    fill_videos
  end  

  # Initialize DLVideo from filename, return a list of videos
  def self.from_file(filename)
    @html = File.open(filename).read

    fill_videos
  end

  # Download videos via one of the methods: 
  # * :download_by_ruby         - Download directly via ruby
  # * :download_by_curl         - Download via curl
  # * :download_by_curl_manual  - Download via curl manually (generate script) 
  def self.download(videos, download_method = :download_by_ruby)
    videos.each { |video| video.send(download_method) }
  end

  private
  
  def download_by_ruby() 
    puts "Downloading #{@filename}..."

    video = File.new(@filename, "wb")
    open(@url) do |f|
      f.each_byte { |c| video.putc c }
    end

    video.close
  end

  def download_by_curl()
    puts "Downloading #{@filename}..."
    
    # Show instant status from curl
    # STDOUT.sync = true
    
    system build_curl_cmd
  end

  def download_by_curl_manual() 
    puts build_curl_cmd
  end

  def self.parse_url(html)
    re = %r{<div class="dlink"><a href="([^"]*)"}
    @html.scan(re)
  end

  def self.parse_filename(html)
    re = %r{FILE NAME <input readonly="readonly" value="(.*?)" }
    @html.scan(re).collect { |title| CGI.unescapeHTML title }
  end

  def self.fill_videos()
    videos = []

    urls, filenames = parse_url(@html), parse_filename(@html) if @html

    urls.length.times do |i|
      videos << DLVideo.new(urls[i][0], filenames[i][0]) 
    end
    
    videos
  end

  def build_curl_cmd()
    %{curl -o "#{@filename}" -L -A "#{@@user_agent}" "#{@url}" 2>&1}
  end
end



if $0 == __FILE__
  abort RDoc::usage unless ARGV.length == 1 || ARGV.length == 2
  
  download_method = case ARGV[1]
                      when '-c': :download_by_curl
                      when '-m': :download_by_curl_manual
                      when '-r': :download_by_ruby   
                      else :download_by_curl
                      end

  TOTAL_RETRY = 5
  TOTAL_RETRY.times do |retry_count|
    videos = DLVideo.from_url(ARGV[0])
    
    if videos.length == 0
      if (retry_count + 1 < TOTAL_RETRY)
        puts "Failed to parse url, retry no.#{retry_count + 1}..."
        sleep 5
      else
        abort "Failed to download"
      end
    else
      DLVideo.download(videos, download_method)
      break
    end
  end
end

__END__
