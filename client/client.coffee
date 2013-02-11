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

  'click #button-passphrase': (ev, tmpl) ->
    $(tmpl.find('#modal-passphrase')).modal {keyboard: true}
    $(tmpl.find('#passphrase-error-msg')).hide
    $(tmpl.find('#passphrase-group')).addClass 'error'
    Meteor.flush()
    tmpl.find('#passphrase-new').focus()
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

cellMetaData = (valuefunc, updatefunc) ->
  {
    value: valuefunc()
    _id: Meteor.uuid()
    updatefunc: updatefunc
  }

Template.passwdlist.helpers {
  entries: () ->
    search = Session.get 'search'
    if search and search != ''
      # TODO think about optimization. Regex in mongodb can be done on an index.
      regexp = new RegExp search, 'i'
      Passwds.find {'title':regexp}, {}
    else
      Passwds.find {}, {}

  passwdcelldecrypt: () ->
    cellMetaData () =>
        pass = Session.get 'pass'
        text =
          try
            if pass and pass != ''
              obj = CryptoJS.Rabbit.decrypt(@password, Session.get('pass'))
              obj.toString(CryptoJS.enc.Utf8)
            else
              null
          catch err
            null
      ,
      (newval) =>
        pass = Session.get 'pass'
        if pass and pass != ''
          encrypted = CryptoJS.Rabbit.encrypt(newval, pass).toString()
          Passwds.update {'_id': @_id}, {'$set': {'password': encrypted}}


  passwdcelltitle: () ->
    cellMetaData () =>
        @title
      ,
      (newval) =>
        Passwds.update {'_id': @_id}, {'$set': {'title': newval}}
        null

  passwdcellusername: () ->
    cellMetaData () =>
        @username
      ,
      (newval) =>
        Passwds.update {'_id': @_id}, {'$set': {'username': newval}}
        null
}

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

Template.usercontent.wrongPassphraseClass = () ->
  if not Session.get 'pass'
    'error'
  else
    ''

Template.usercontent.userId = @userId

Template.new.newDisabled = () ->
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
        cancel.call this, ev
      else if ev.type == 'keyup' and ev.which == 13 or
              ev.type == 'focusout'
        value = ev.target.value
        if value
          ok.call this, value, ev
        else
          cancel.call this, ev
      null
  events

Template.passwdcell.events {
  'dblclick .cell' : (ev, tmpl) ->
    if @value
      Session.set 'editing_cell', @_id
      Meteor.flush()
      activateInput(tmpl.find('#cell-input'))
}

Template.passwdcell.editing = () ->
  Session.equals 'editing_cell', @_id

Template.passwdlist.events(okCancelEvents(
  '#cell-input',
  {
    ok: (value, ev) ->
      if value != @value and value != ''
        @updatefunc(value)
      Session.set 'editing_cell', null
    cancel: (ev) ->
      Session.set 'editing_cell', null
  }
))
