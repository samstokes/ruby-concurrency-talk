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

def cache_bust
  {'Cookie' => "cache_bust=#{rand 10_000}"}
end

def link_content(url)
  uri = URI.parse(url)
  unless uri.host
    return link_content("https://news.ycombinator.com/#{url}")
  end
  http = EventMachine::HttpRequest.new(uri)
  puts "getting #{url}"
  http.get(head: cache_bust).callback { puts "got #{url}" }
end

get '/' do
  <<-HTML
    <form method=GET action="/grep">
      Regex to filter out:
      <input name="regex" />
    </form>
  HTML
end

get '/grep' do
  callback = env['async.callback']

  regex = Regexp.new(params.fetch('regex'), 'i')
  http = EventMachine::HttpRequest.new('https://news.ycombinator.com/').get(head: cache_bust)
  http.callback do
    html = http.response

    document = Nokogiri(html)

    links = hnlinks(document)

    links_bad_title = links.select {|link| link.text =~ regex }
    link_contents = {}
    finish_if_done = lambda do
      if link_contents.size == links.size
        links_bad_content = link_contents.select do |_, contents|
            contents && contents =~ regex
        end.map {|bad_link, _| bad_link }

        bad_links = (links_bad_title + links_bad_content).uniq

        bad_links.each do |bad_link|
          bad_link.parent.parent.next_sibling.remove
          bad_link.parent.parent.remove
        end

        callback.call [200, {}, [document.to_s]]
      end
    end

    links.each do |link|
      link_content(link[:href]).callback do |link_http|
        link_contents[link] = link_http.response
        finish_if_done.call
      end.errback do |link_http|
        puts "Got #{link_http.response_header.status} from #{link[:href]}"
        link_contents[link] = nil
        finish_if_done.call
      end
    end
  end

  [-1, {}, []]
  # or "throw :async"
end

get '/:asset' do |asset|
  callback = env['async.callback']
  http = EventMachine::HttpRequest.new('https://news.ycombinator.com/' + asset).get
  http.callback do
    callback.call [
      http.response_header.status,
      http.response_header,
      [http.response]
    ]
  end
  [-1, {}, []]
end
