Passwds = new Meteor.Collection "passwds"

if Meteor.isServer
  Meteor.startup () ->
    # TODO: Wait for meteor to support _ensureIndex officially in its api.
    #       _ensureIndex is a temp solution only.
    Passwds._ensureIndex {"user" : 1}, {"unique" : true}

Passwds.allow {
  'remove': (userId, passwds) ->
    not _.any passwds, (passwd) ->
      passwd.user != userId
}
