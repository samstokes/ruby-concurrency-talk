# vim:ft=ruby

require 'net/http'

require 'nokogiri'
require 'sinatra'

def hnlinks(document)
  links = document / 'td.title > a'
  links.reject {|link| link.text == 'More' }
end

def link_content(url)
  uri = URI.parse(url)
  unless uri.host
    return link_content("https://news.ycombinator.com/#{url}")
  end
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  puts "getting #{url}"
  path = uri.path.empty? ? '/' : uri.path
  http.get(path).body
end

get '/grep' do
  regex = Regexp.new(params.fetch('regex'), 'i')
  http = Net::HTTP.new('news.ycombinator.com', 443)
  http.use_ssl = true
  html = http.get('/').body

  document = Nokogiri(html)

  links = hnlinks(document)

  links_bad_title = links.select {|link| link.text =~ regex }

  link_contents = links.map do |link|
    Thread.new do
      link_content(link[:href])
    end
  end.map(&:value)
  links_bad_content = links.
    zip(link_contents).
    select {|link, content| content.scan(regex).size > 2 }.
    map {|link, _| link }

  bad_links = (links_bad_title + links_bad_content).uniq

  bad_links.each do |link|
    link.parent.parent.next_sibling.remove
    link.parent.parent.remove
  end

  document.to_s
end
