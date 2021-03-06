# res_version file update strategy:
#
# Every release pacakge has a default res_version file to ensure the cache feature working normally. It's always the newest version at release time.
#
# It'll download from the poi's server if there's a new one exist. We should update it regularly.
#
# The problem is how we update it:
# Step.1 Get the list of all resource files. (Use Shimakaze-Go's static_res.json file)
# Step.2 Get the list of resource files that has changed. (Compare the newest static_res.json with the current version)
# Step.3 Get the version and filesize info of the changed resource files. (Run the game, print the corresponding request url log)
# Step.4 Genarate a new res_version file. (Manually modify the old res_version file)

fs = require('fs')
url = require('url')
util = require('./util')

resVersionPath = 'data/static_res.json'
resVersionRealPath = global.appDataPath + '/' + resVersionPath

cacheData = {}

exports.initCache = () ->
  # TODO: Download from server
  try
    data = JSON.parse fs.readFileSync resVersionRealPath
  catch err
    console.log err if err
    data = JSON.parse fs.readFileSync resVersionPath
    util.copyFile resVersionPath, resVersionRealPath
  for res in data.list
    cacheData[res.res_path] = res

# Load File From Cache
exports.loadCacheFile = (req, res, callback) ->
  # These two swf files are source code files, not resource files
  # Caching these files may cause illegal logic error I guess?
  if req.url.indexOf('/kcs/Core.swf') != -1 || req.url.indexOf('/kcs/mainD2.swf') != -1
    callback true
    return
  if req.url.indexOf('/kcs/') != -1
    # fs.appendFile "#{global.appDataPath}/kcs/kcs.log", "#{req.method} #{req.url}\nPostData: #{JSON.stringify req.postData, null, 2}\n\n\n", (err) ->
    #   console.log err if err?
    # Get FilePath
    filePath = url.parse(req.url).pathname
    query = url.parse(req.url).query
    requestVersion = 1
    if query?
      requestVersion = query.substr ('VERSION='.length)
    cacheInfo = cacheData[filePath]
    if !cacheInfo? || !requestVersion?
      callback true
      return
    cacheSize = cacheInfo.file_size
    cacheVersion = cacheInfo.version
    # Check FileVersion
    if !cacheSize? #|| !cacheVersion? || requestVersion != cacheVersion
      callback true
      return
    # Get FileSize
    fileAbsolutePath = "#{global.appDataPath}#{filePath}"
    fs.stat fileAbsolutePath, (err, stat) ->
      if !err?
        # Check FileSize
        fileSize = stat.size
        if fileSize != cacheSize
          callback true
          return
        # Read FileData
        fs.readFile fileAbsolutePath, (err, data) ->
          if !err
            date = new Date().toGMTString()
            # console.log "Load File From Cache: #{filePath}, Size: #{fileSize}, Date: #{date}, Version: #{requestVersion}"
            res.writeHead 200, "{
                                  \"date\":\"#{date}\",
                                  \"server\":\"Apache\",
                                  \"last-modified\":\"Wed, 23 Apr 2014 05:46:42 GMT\",
                                  \"accept-ranges\":\"bytes\",
                                  \"content-length\":\"#{fileSize}\",
                                  \"cache-control\":\"max-age=2592000, public\",
                                  \"connection\":\"close\",
                                  \"content-type\":\"application/x-shockwave-flash\"
                              }"
            res.write data
            res.end()
            callback false
          else
            console.log err
            callback true
      else
        console.log err
        callback true
  else
    callback true

# Save File To Cache
exports.saveCacheFile = (req, data) ->
  return if req.url.indexOf('/kcs/Core.swf') != -1 || req.url.indexOf('/kcs/mainD2.swf') != -1
  if req.url.indexOf('/kcs/') != -1
    # Get FilePath
    filePath = url.parse(req.url).pathname
    # query = url.parse(req.url).query
    # requestVersion = 1
    # if query?
    #   requestVersion = query.substr ('VERSION='.length)

    fileAbsolutePath = "#{global.appDataPath}#{filePath}"
    util.guaranteeFilePath fileAbsolutePath
    # Save File
    fs.writeFile fileAbsolutePath, data, (err) ->
      if err?
        console.log err
      else
        console.log "Save Cache File: #{filePath}" if !err
        # fs.stat fileAbsolutePath, (err, stat) ->
        #   if err
        #     console.log err
        #   else
        #     fileSize = stat.size
        #     cacheData[filePath] = "{
        #                             \"res_path\": \"#{filePath}\",
        #                             \"version\": \"#{requestVersion}\",
        #                             \"file_size\": \"#{fileSize}\",
        #                           }\"

