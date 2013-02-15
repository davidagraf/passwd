require = __meteor_bootstrap__.require
Future = require 'fibers/future'

Meteor.startup () ->
  # code to run on server at startup
  # console.log "server startup"
  null

Meteor.publish 'passwds', () ->
  Passwds.find {'user': @userId}, {}

Meteor.publish 'pphashes', ()->
  PpHashes.find {'user': @userId}, {}

Meteor.methods {
  insertPasswd: (title, username, password) ->
    Passwds.insert {
      'user': @userId
      'title': title
      'username': username
      'password': password
    }
  insertPasswdObj: (obj) ->
    if obj.user == @userId
      Passwds.insert obj
  insertPpHash: (pphash) ->
    PpHashes.update {
      'user': @userId
    },
    {
      '$set': { 'pphash': pphash }
    },
    {
      'upsert': true
    }
  deleteEverything: () ->
    Passwds.remove {'user': @userId }
    PpHashes.remove {'user': @userId }
}

Meteor.startup () ->
  Meteor.Router.add
    '/:user/passwds.csv': (userId) ->
      @response.writeHead 200, {
        'Content-Type':'text/csv'
      }
      entries = Passwds.find {'user': userId}, {}
      @response.write "Title,Username,Encoded Password\n"
      entries.forEach (entry) =>
        @response.write "#{entry.title},#{entry.username},#{entry.password}\n"
      @response.end()
