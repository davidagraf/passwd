Meteor.subscribe "passwds"

Template.new.events {
  'click #new-btn': () ->
    Meteor.call 'insertPasswd',
                $('#new-title').val(),
                $('#new-username').val(),
                $('#new-password').val()
    null
}

Template.passwdlist.entries = () ->
  Passwds.find {}, {}
