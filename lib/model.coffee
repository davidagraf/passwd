Passwds = new Meteor.Collection "passwds"
PpHashes = new Meteor.Collection "pphashes"

if Meteor.isServer
  Meteor.startup () ->
    # TODO: Wait for meteor to support _ensureIndex officially in its api.
    #       _ensureIndex is a temp solution only.
    Passwds._ensureIndex {"user" : 1}, {"unique" : false}
    PpHashes._ensureIndex {"user" : 1}, {"unique" : false}

Passwds.allow {
  'remove': (userId, passwds) ->
    not _.any passwds, (passwd) ->
      passwd.user != userId
  'update': (userId, passwds, fields, modifier) ->
    _.all passwds, (passwd) ->
      passwd.user == userId
}

if Meteor.isClient
  window.Passwds = Passwds
  window.PpHashes = PpHashes
else if Meteor.isServer
  @Passwds = Passwds
  @PpHashes = PpHashes
