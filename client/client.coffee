Meteor.subscribe "passwds"
Meteor.subscribe "pphashes"

Template.new.events {
  'click #button-new': () ->
    htmlTitle = $('#new-title')
    htmlUsername = $('#new-username')
    htmlPass = $('#new-password')
    pass = htmlPass.val()
    encrypted = CryptoJS.Rabbit.encrypt(pass, Session.get('pass')).toString()
    Meteor.call 'insertPasswd',
                @userId,
                htmlTitle.val(),
                htmlUsername.val(),
                encrypted

    htmlTitle.val ''
    htmlUsername.val ''
    htmlPass.val ''

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

  'click #button-passphrase': (ev) ->
    $('#modal-passphrase').modal {keyboard: true}
    $('#passphrase-error-msg').hide
    $('#passphrase-group').addClass 'error'
    null

  'click #button-passphrase-change': (ev) ->
    newPp = $('#passphrase-new').val()
    oldPp = Session.get 'pass'
    Session.set 'pass', newPp
    $('#passphrase').val newPp

    # TODO This operation is unsafe. If something crashes, the database
    # entries are fucked up. On solution would be versioning: Always keep the
    # old encrypted passwords and store the current version in the pphash 
    # collection
    if oldPp
      entries = Passwds.find {}, {}
      entries.forEach (entry) ->
        oldEncrypted = entry.password
        passObj = CryptoJS.Rabbit.decrypt(oldEncrypted, oldPp)
        newEncrypted = CryptoJS.Rabbit.encrypt(passObj, Session.get('pass')).toString()
        Passwds.update {'_id' : entry._id}, {'$set' : {'password':newEncrypted}}

    hash = CryptoJS.SHA3(newPp).toString()
    Meteor.call 'insertPpHash',
                @userId,
                hash


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

Template.usercontent.wrongPassphrase = () ->
  not Session.get 'pass'

Template.usercontent.userId = @userId

Template.new.wrongPassphrase = () ->
  not Session.get 'pass'

activateInput = (input) ->
  input.focus()
  input.select()

# Code for inplace editing

# Returns an event map that handles the "escape" and "return" keys and
# "blur" events on a text input (given by selector) and interprets them as
# "ok" or "cancel"

okCancelEvents = (selector, callbacks) ->
  ok = callbacks.ok or () -> null
  cancel = callbacks.cancel or () -> null

  events = {}
  events["keyup #{selector}, keydown #{selector}, focusout #{selector}"] =
    (ev) ->
      if ev.type == 'keydown' and ev.which == 27
        canncel.call this, ev
      else if ev.type == 'keyup' and ev.which == 13 or
              ev.type == 'focusout'
        value = ev.target.value
        if value
          ok.call this, value, ev
        else
          cancel.call this, ev
      null
  events

Template.passwdlist.events {
  'dblclick .row' : (ev, tmpl) ->
    Session.set 'editing_row', @_id
    Meteor.flush()
    activateInput(tmpl.find('#table-input'))
}

Template.passwdlist.editing = () ->
  Session.equals 'editing_row', @_id

Template.passwdlist.events(okCancelEvents(
  '#table-input',
  {
    ok: (value) ->
      Session.set 'editing_row', null
    cancel: () ->
      Session.setx 'editing_row', null
  }
))
