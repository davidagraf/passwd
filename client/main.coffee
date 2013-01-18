Meteor.subscribe "passwds"

Template.new.events {
  'click #new-btn': () ->
    Meteor.call 'insertPasswd',
                $('#new-title').val(),
                $('#new-username').val(),
                $('#new-password').val()
    null
}

Template.usercontent.events {
  'change #passphrase': (ev) ->
    # big question: is this secure?
    # if not, the passphrase needs to be stored in a custom reactive data
    # source, # see: http://docs.meteor.com/#meteor_deps
    Session.set 'pass', ev.srcElement.value
}

Template.passwdlist.entries = () ->
  Passwds.find {}, {}
