# Description:
#   A way to interact with the Google Images API.
#
# Configuration
#   HUBOT_GOOGLE_CSE_KEY - Your Google developer API key
#   HUBOT_GOOGLE_CSE_ID - The ID of your Custom Search Engine
#   HUBOT_MUSTACHIFY_URL - Optional. Allow you to use your own mustachify instance.
#
# Commands:
#   hubot image me <query> - The Original. Queries Google Images for <query> and returns a random top result.
#   hubot animate me <query> - The same thing as `image me`, except adds a few parameters to try to return an animated GIF instead.
#   hubot mustache me <url> - Adds a mustache to the specified URL.
#   hubot mustache me <query> - Searches Google Images for the specified query and mustaches it.

module.exports = (robot) ->
  robot.hear /^(image|img)( me| ma)? (.*)/i, (msg) ->
    imageMe msg, msg.match[3], (url) ->
      msg.send url

  robot.hear /^(animate|gif)( me| ma)? (.*)/i, (msg) ->
    imageMe msg, msg.match[3], true, (url) ->
      msg.send url

imageMe = (msg, query, animated, faces, cb) ->
  cb = animated if typeof animated == 'function'
  cb = faces if typeof faces == 'function'
  googleCseId = process.env.HUBOT_GOOGLE_CSE_ID
  # Using Google Custom Search API
  googleApiKey = process.env.HUBOT_GOOGLE_CSE_KEY
  if !googleApiKey
    msg.robot.logger.error "Missing environment variable HUBOT_GOOGLE_CSE_KEY"
    msg.send "Missing server environment variable HUBOT_GOOGLE_CSE_KEY."
    return
  q =
    q: query,
    searchType:'image',
    fields:'items(link)',
    cx: googleCseId,
    key: googleApiKey
  if animated is true
    q.fileType = 'gif'
    q.hq = 'animated'
    q.tbs = 'itp:animated'
  if faces is true
    q.imgType = 'face'
  url = 'https://www.googleapis.com/customsearch/v1'
  msg.http(url)
    .query(q)
    .get() (err, res, body) ->
      if err
        msg.send "Encountered an error :( #{err}"
        return
      if res.statusCode isnt 200
        msg.robot.logger.error body
        msg.send "Bad HTTP response :( #{res.statusCode}"
        return
      response = JSON.parse(body)
      if response?.items
        image = msg.random response.items
        cb ensureResult(image.link, animated)
      else
        msg.send "Oops. I had trouble searching '#{query}'. Try later."
        ((error) ->
          msg.robot.logger.error error.message
          msg.robot.logger
            .error "(see #{error.extendedHelp})" if error.extendedHelp
        ) error for error in response.error.errors if response.error?.errors

# Forces giphy result to use animated version
ensureResult = (url, animated) ->
  if animated is true
    ensureImageExtension url.replace(
      /(giphy\.com\/.*)\/.+_s.gif$/,
      '$1/giphy.gif')
  else
    ensureImageExtension url

# Forces the URL look like an image URL by adding `#.png`
ensureImageExtension = (url) ->
  if /(png|jpe?g|gif)$/i.test(url)
    url
  else
    "#{url}#.png"
