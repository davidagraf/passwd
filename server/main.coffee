Meteor.startup () ->
  # code to run on server at startup
  # console.log "server startup"
  null

Meteor.publish 'passwds', () ->
  Passwds.find {'user': @userId}, {}

Meteor.methods {
  'insertPasswd': (title, username, password) ->
    Passwds.insert {
      'user': this.userId
      'title': title
      'username': username
      'password':password
    }
}
