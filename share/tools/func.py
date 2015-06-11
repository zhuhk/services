#!/bin/env python

import urlparse
import posixpath
from bs4 import BeautifulSoup

def urljoin(base,url):
  join = urlparse.urljoin(base,url)
  url = urlparse.urlparse(join)
  path = posixpath.normpath(url[2])
  return urlparse.urlunparse(
      (url.scheme,url.netloc,path,url.params,url.query,url.fragment)
      )

def extract_images(base,html):
  images = []
  soup = BeautifulSoup(html)
  for img in soup.find_all("img"):
    if img.has_attr("src"):
      images.append(urljoin(base,img["src"]))
  return images

def HammingDistance(value1, value2):
  x = (value1 ^ value2) & ((1 << 64) - 1)
  ans = 0
  while x:
    ans += 1
    x &= x - 1
  return ans

if __name__ == '__main__' :
  assert(HammingDistance(15784426920315087817,6741816074229365743)==24)
  assert(HammingDistance(15784426920315087817,15784426920315087817)==0)

  assert(urljoin("http://abc.com/base/base.html", "../../1.jpg") == "http://abc.com/1.jpg")
  assert(urljoin("http://abc.com/base/base.html", "./1.jpg") == "http://abc.com/base/1.jpg")
  assert(urljoin("http://abc.com/base/base.html", "1.jpg") == "http://abc.com/base/1.jpg")
  assert(urljoin("http://abc.com/base/base.html", "/1.jpg") == "http://abc.com/1.jpg")

  print "pass - all cases is succ"
    
