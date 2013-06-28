# vim:ft=ruby

require 'net/http'

require 'em-http-request'
require 'nokogiri'
require 'sinatra'
require 'thin'

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
  callback = env['async.callback']

  regex = Regexp.new(params.fetch('regex'), 'i')
  http = EventMachine::HttpRequest.new('https://news.ycombinator.com/').get
  http.callback do
    html = http.response

    document = Nokogiri(html)

    links = hnlinks(document)

    links_bad_title = links.select {|link| link.text =~ regex }
    links_bad_content = links.select {|link| link_content(link[:href]).scan(regex).size > 2 }
    bad_links = (links_bad_title + links_bad_content).uniq

    bad_links.each do |link|
      link.parent.parent.next_sibling.remove
      link.parent.parent.remove
    end

    callback.call [200, {}, [document.to_s]]
  end

  [-1, {}, []]
  # or "throw :async"
end
