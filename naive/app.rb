# vim:ft=ruby

require 'net/http'

require 'nokogiri'
require 'sinatra'

def hnlinks(document)
  links = document / 'td.title > a'
  links.reject {|link| link.text == 'More' }
end

def cache_bust
  {'Cookie' => "cache_bust=#{rand 10_000}"}
end

def link_content(url)
  uri = URI.parse(url)
  unless uri.host
    return link_content("https://news.ycombinator.com/#{url}")
  end
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  path = uri.path.empty? ? '/' : uri.path
  http.get(path, cache_bust).body.tap do
    puts "got #{url}"
  end
end

get '/grep' do
  regex = Regexp.new(params.fetch('regex'), 'i')
  http = Net::HTTP.new('news.ycombinator.com', 443)
  http.use_ssl = true
  html = http.get('/', cache_bust).body

  document = Nokogiri(html)

  links = hnlinks(document)

  links_bad_title = links.select {|link| link.text =~ regex }
  links_bad_content = links.select {|link| link_content(link[:href]).scan(regex).size > 2 }
  bad_links = (links_bad_title + links_bad_content).uniq

  bad_links.each do |link|
    link.parent.parent.next_sibling.remove
    link.parent.parent.remove
  end

  document.to_s
end
