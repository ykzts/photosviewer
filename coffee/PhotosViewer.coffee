# -*- coding: utf-8 -*-

class PhotosViewer
  self = null
  constructor: ->
    self = this

    self.pathname = '/'

    self.username = null
    self.page = null

    self.cache = {}

    self.result = document.getElementById('result')

    self.html_maker = new HTMLMaker(document)

    self.uri_rules = new URIRules()
    self.uri_rules.set('/', ->
      self.init()
      return 'tumblr photos viewer'
    ).set('/(\\w+)(?:\\?page=(\\d+))?', (_, username, page) ->
      self.username = username
      self.page = (page or 1) * 1
      self.request_tumblr(self.username, self.page)
      return "#{self.page} < #{self.username} < tumblr photos viewer"
    )
    self.uri_rules.http404 = ->
      self.output_result('404 Not found.')
      return

    self.add_event()

    return

  add_event: ->
    window.addEventListener('popstate', self.popstate, false)
    document.addEventListener('DOMContentLoaded', self.loaded, false)
    return

  loaded: ->
    self.start()

    form = document.getElementsByTagName('form').item(0)
    text_field = document.getElementById('tumblr_username')
    text_field.value = self.username if self.username
    form.onsubmit = ->
      self.init()
      text_field.blur()
      self.username = text_field.value
      self.change(self.get_uri(self.username))
      return false

    return

  popstate: ->
    self.start()
    return

  start: ->
    pathname = location.pathname + (location.search or '')
    self.init()
    self.change(pathname)
    return

  init: ->
    window.removeEventListener('scroll', self.scroll, false)
    while self.result.hasChildNodes()
      self.result.removeChild(self.result.firstChild)
    return

  request_tumblr: (username, page) ->
    self.output_result('loading...')

    unless self.cache[username]
      self.cache[username] = {}
    if self.cache[username][page]
      self.append_posts(self.cache[username][page])
      return

    tumblr = new Tumblr(username)
    tumblr.page = page or '1'
    tumblr.type = 'photo'
    tumblr.num = 10
    tumblr.callback = (json) ->
      self.cache[username][page] = json.posts
      self.append_posts(self.cache[username][page])
      return
    tumblr.timeout = 2 * 1000
    tumblr.ontimeout = ->
      message = self.output_result('timeout...')
      message.addEventListener('click', self.reload, false)
      return
    tumblr.send_request()
    return

  append_posts: (posts) ->
    self.output_result(posts)
    window.addEventListener('scroll', self.scroll, false)
    return

  output_result: (arg) ->
    node = null

    self.delete_message()

    h = self.html_maker
    switch typeof arg
      when 'object'
        self.output_result_for_posts(arg)
        return
      when 'string'
        node = h.html('p', [
          h.html('@class', 'message')
          arg
        ])
        self.result.appendChild(node)
    return node

  output_result_for_posts: (posts) ->
    h = self.html_maker
    for post, i in posts
      section = document.getElementById('_template').cloneNode(true)
      section.removeAttribute('id')
      title = section.getElementsByClassName('title').item(0)
      title.appendChild(h.html('a', [
        h.html('@href', post['url'])
        post['url']
      ]))
      photo = section.getElementsByClassName('photo').item(0)
      photo.appendChild(h.html('img', [
        h.html('@src', post['photo-url-1280'])
        h.html('@alt', ' ')
      ]))
      section.addEventListener('click', ->
        if next_section = this.nextElementSibling
          scroll(0, next_section.offsetTop)
        return 
      , false)
      self.result.appendChild(section)
    return

  delete_message: ->
    message = self.result.getElementsByClassName('message').item(0)
    message.parentNode.removeChild(message) if message
    return

  scroll: ->
    sections = self.result.getElementsByTagName('section')
    return if sections.length is 0 or \
      window.scrollY < sections.item(sections.length-2).offsetTop
    window.removeEventListener('scroll', arguments.callee)
    self.change(self.get_uri(self.username, self.page + 1))
    return

  change: (uri) ->
    self.pathname = uri
    self.uri_rules.change(uri)
    return

  reload: ->
    self.change(self.pathname)
    return

  get_uri: (username, page) ->
    uri = '/'
    uri += username if username
    uri += ('?page=' + page) if page
    return uri
