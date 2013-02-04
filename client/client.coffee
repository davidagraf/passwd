Meteor.subscribe "passwds"
Meteor.subscribe "pphashes"

Template.new.events {
  'click #new-btn': () ->
    pass = $('#new-password').val()
    encrypted = CryptoJS.Rabbit.encrypt(pass, Session.get('pass')).toString()
    Meteor.call 'insertPasswd',
                @userId,
                $('#new-title').val(),
                $('#new-username').val(),
                encrypted
    null
}

Template.usercontent.events {
  'keyup #passphrase': (ev) ->
    passphrase = ev.srcElement.value
    storedHash = PpHashes.findOne {}, {}

    # check if entered passphrase is valid
    currentHash = CryptoJS.SHA3(passphrase).toString()

    if storedHash and (storedHash.pphash == currentHash)
      # TODO: is this secure?
      # if not, the passphrase needs to be stored in a custom reactive data
      # source, # see: http://docs.meteor.com/#meteor_deps
      Session.set 'pass', ev.srcElement.value
    else
      Session.set 'pass'

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
      ''
  catch err
    ''

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
    $('#passphrase-error-msg').hide
    $('#passphrase-group').addClass 'error'
    null

  'click #button-passphrase-change': (ev) ->
    newPp = $('#passphrase-new').val()
    Session.set 'pass', newPp
    $('#passphrase').val newPp

    hash = CryptoJS.SHA3(newPp).toString()
    Meteor.call 'insertPpHash',
                @userId,
                hash

    null
}
