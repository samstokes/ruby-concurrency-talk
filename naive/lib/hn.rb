module HN
  def hnlinks(document)
    links = document / 'td.title > a'
    links.reject {|link| link.text == 'More' }
  end
end
