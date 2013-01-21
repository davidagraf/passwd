Meteor.subscribe "passwds"

Template.new.events {
  'click #new-btn': () ->
    pass = $('#new-password').val()
    encrypted = CryptoJS.Rabbit.encrypt(pass, Session.get('pass')).toString()
    Meteor.call 'insertPasswd',
                $('#new-title').val(),
                $('#new-username').val(),
                encrypted
    null
}

Template.usercontent.events {
  'keyup #passphrase': (ev) ->
    # big question: is this secure?
    # if not, the passphrase needs to be stored in a custom reactive data
    # source, # see: http://docs.meteor.com/#meteor_deps
    Session.set 'pass', ev.srcElement.value
}

Template.passwdlist.entries = () ->
  Passwds.find {}, {}

Template.passwdlist.decrypt = () ->
  pass = Session.get 'pass'
  try
    if pass and pass != ''
      obj = CryptoJS.Rabbit.decrypt(this.password, Session.get('pass'))
      obj.toString(CryptoJS.enc.Utf8)
    else
      this.password
  catch err
    this.password
