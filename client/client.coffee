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
    # TODO: is this secure?
    # if not, the passphrase needs to be stored in a custom reactive data
    # source, # see: http://docs.meteor.com/#meteor_deps
    Session.set 'pass', ev.srcElement.value
    null

  'keyup #search': (ev) ->
    Session.set 'search', ev.srcElement.value
    null
}

Template.passwdlist.entries = () ->
  search = Session.get 'search'
  if search and search != ''
    # TODO think about optimization. Regex in mongodb can be done on an index.
    regexp = new RegExp search, 'i'
    Passwds.find {'title':regexp}, {}
  else
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

Template.passwdlist.events {
  'click .trash': (ev) ->
    Passwds.remove {'_id': @_id}
    false
}

Meteor.startup () ->
  $('#button-passphrase').tooltip {
                                    title: 'replace old pwd with current'
                                    placement: 'bottom'
                                  }

Template.usercontent.events {
  'click #button-passphrase': (ev) ->
    $('#modal-passphrase').modal {keyboard: true}
    Session.set 'new-passphrase-equal', false
    $('#passphrase-error-msg').hide
    $('#passphrase-group').addClass 'error'
    null

  'click #button-passphrase-change': (ev) ->
    val = $('#passphrase-new').val()
}
