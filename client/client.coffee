Meteor.subscribe "passwds"
Meteor.subscribe "pphashes", () ->
  # put cursor into passphrase if necessary
  if not PpHashes.findOne()?
    Session.set 'passphrase-changing', true
  else if not Session.get('passphrase')?
    Session.set 'passphrase-setting', true
  null


HTMLFormTypes =
  password : 0x001
  textarea : 0x010

activateInput = (input) ->
  isTextarea = input.classList.contains 'textarea'
  input.focus()
  if not isTextarea
    input.select()
  null

decrypt = (encrypted) ->
  passphrase = Session.get 'passphrase'
  if not encrypted or not passphrase
    null
  else
    obj = CryptoJS.Rabbit.decrypt(encrypted, passphrase)
    obj.toString(CryptoJS.enc.Utf8)

encrypt = (text) ->
  passphrase = Session.get 'passphrase'
  if not text or not passphrase
    null
  else
    CryptoJS.Rabbit.encrypt(text, passphrase).toString()


# Returns an event map that handles the "escape" and "return" keys and
# "blur" events on a text input (given by selector) and interprets them as
# "ok" or "cancel"
okCancelEvents = (selector, callbacks) ->
  ok = callbacks.ok or () -> null
  cancel = callbacks.cancel or () -> null

  events = {}
  events["keyup #{selector}, keydown #{selector}, focusout #{selector}"] =
    (ev, tmpl) ->
      isTextarea = ev.target.classList.contains 'textarea'
      if ev.type == 'keydown' and ev.which == 27
        cancel.call this, ev
        false
      else if (not isTextarea and
                ev.type == 'keyup' and ev.which == 13) or
                ev.type == 'focusout'
        value = ev.target.value
        if isTextarea or value
          ok.call this, value, ev, tmpl
        else
          cancel.call this, ev, tmpl
        false
      else
        true
  events

Template.globalbtns.rendered = () ->
  $(@find('#button-delete-everything')).tooltip {
      title: 'delete all data'
      placement: 'bottom'
  }
  $(@find('#button-csv')).tooltip {
      title: 'export all data as CSV (Rabbit encoded)'
      placement: 'bottom'
  }
  null

Template.globalbtns.events {
  'click #button-csv': () ->
    bb = new BlobBuilder()
    entries = Passwds.find {}, {}
    bb.append "Title,Username,Password\n"
    entries.forEach (entry) =>
      bb.append "#{entry.title},#{entry.username},#{entry.password}\n"
    blob = bb.getBlob("text/csv;charset=" + document.characterSet)
    saveAs(blob, "passwd.csv")
    null

  'click #button-delete-everything': (ev, tmpl) ->
    Session.set 'passphrase'
    Session.set 'passphrase-changing'
    Session.set 'search'
    Session.set 'passphrase-setting'
    Session.set 'passwd-undo'
    Meteor.call 'deleteEverything'
    tmpl.find('#passphrase').value = ''
}


Template.usercontent.events {
  'keyup #search': (ev) ->
    Session.set 'search', ev.target.value
    null
}

deleteCurrentUndo = () ->
  Session.set 'passwd-undo'

generatePasswdUndo = (obj, isUpdate) ->
  isUpdate = isUpdate or false
  insertObj = {}
  for own key, value of obj
    if not isUpdate or ( key != '_id' and key != 'user')
      insertObj[key] = value
  undoObj = {
    _id: obj._id
    insert: insertObj
    isUpdate: isUpdate
  }
  Session.set 'passwd-undo', undoObj
  null

Template.undo.events {
  'click #button-undo': () ->
    undoObj = Session.get 'passwd-undo'
    if undoObj.isUpdate
      Passwds.update {'_id' : undoObj._id}, {'$set': undoObj.insert}
    else
      Meteor.call 'insertPasswdObj',
                  undoObj.insert
    deleteCurrentUndo()
}

Template.undo.helpers {
  undoHiddenClass: () ->
    if Session.get('passwd-undo')?
      ''
    else
      'undo-hidden'
}

Template.passphrase.rendered = () ->
  $(@find('#button-passphrase-set')).tooltip {
      title: 'enter passphrase in use'
      placement: 'bottom'
  }
  $(@find('#button-passphrase-change')).tooltip {
      title: 'set / change passphrase'
      placement: 'bottom'
  }
  if Session.get('passphrase-setting') or Session.get('passphrase-changing')
    activateInput(this.find('#passphrase'))
  null

Template.passphrase.events {
  'keyup #passphrase': (ev) ->
    if not Session.get('passphrase-setting')?
      return null

    passphrase = ev.target.value
    storedHash = PpHashes.findOne {}, {}

    # check if entered passphrase is valid
    currentHash = CryptoJS.SHA3(passphrase).toString()

    if storedHash and (storedHash.pphash == currentHash)
      # TODO: is this secure?
      # if not, the passphrase needs to be stored in a custom reactive data
      # source, # see: http://docs.meteor.com/#meteor_deps
      Session.set 'passphrase', ev.target.value
    else
      Session.set 'passphrase'

    null

  'click #button-passphrase-set': (ev, tmpl) ->
    Session.set 'passphrase-setting', true
    null

  'click #button-passphrase-change': (ev, tmpl) ->
    Session.set 'passphrase-changing', true
    null
}

changePassphrase = (newPp) ->
  oldPp = Session.get 'passphrase'
  Session.set 'passphrase', newPp
  deleteCurrentUndo()

  # TODO This operation is unsafe. If something crashes, the database
  # entries are fucked up. On solution would be versioning: Always keep the
  # old encrypted passwords and store the current version in the pphash 
  # collection
  if oldPp
    entries = Passwds.find {}, {}
    entries.forEach (entry) ->
      oldEncrypted = entry.password
      decrypted = decrypt oldEncrypted
      newEncrypted =  encrypt decrypted
      Passwds.update {'_id' : entry._id}, {'$set' : {'password':newEncrypted}}

  hash = CryptoJS.SHA3(newPp).toString()
  Meteor.call 'insertPpHash',
              hash

  null

Template.passphrase.helpers {
  validPassphrase: () ->
    Session.get('passphrase')?
  inputPassphrase: () ->
    Session.get('passphrase-setting')? or Session.get('passphrase-changing')?
  btnSetPassphrase: () ->
    not Session.get('passphrase-setting')? and not Session.get('passphrase')? and
      PpHashes.findOne()?
  passphraseError: () ->
    if not Session.get('passphrase')? and not Session.get('passphrase-changing')?
      'error'
    else
      ''
  btnChangePassphrase: () ->
    not Session.get('passphrase-changing')? and (Session.get('passphrase')? or not PpHashes.findOne()?)
  userId: @userId
}

Template.passphrase.events(okCancelEvents(
  '#passphrase',
  {
    ok: (value, ev) ->
      if Session.get('passphrase-setting')?
        Session.set 'passphrase-setting', null
        if not Session.get 'passphrase'
          ev.target.value = ''
      else if Session.get('passphrase-changing')?
        Session.set 'passphrase-changing', null
        changePassphrase ev.target.value
        ev.target.value = Session.get 'passphrase'
      null
    cancel: (ev) ->
      if Session.get('passphrase-setting')?
        Session.set 'passphrase-setting', null
      else if Session.get('passphrase-changing')?
        Session.set 'passphrase-changing', null
        ev.target.value = Session.get 'passphrase'
      null
  }
))



cellMetaData = (valuefunc, updatefunc, formtype) ->
  value = valuefunc()
  {
    value: if not value then '' else value
    formtype: formtype
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

  passwdcellpassword: () ->
    cellMetaData () =>
        decrypt @password
      ,
      (newval) =>
        encrypted = encrypt newval
        generatePasswdUndo this, true
        Passwds.update {'_id': @_id}, {'$set': {'password': encrypted}}
      ,
      HTMLFormTypes.password

  passwdcelltitle: () ->
    cellMetaData () =>
        @title
      ,
      (newval) =>
        generatePasswdUndo this, true
        Passwds.update {'_id': @_id}, {'$set': {'title': newval}}
        null

  passwdcellusername: () ->
    cellMetaData () =>
        @username
      ,
      (newval) =>
        generatePasswdUndo this, true
        Passwds.update {'_id': @_id}, {'$set': {'username': newval}}
        null

  passwdcellnotes: () ->
    cellMetaData () =>
        decrypt @notes
      ,
      (newval) =>
        encrypted = encrypt newval
        generatePasswdUndo this, true
        Passwds.update {'_id': @_id}, {'$set': {'notes': encrypted}}
        null
      ,
      HTMLFormTypes.textarea

}

Template.passwdlist.events {
  'click .cell-trash': (ev) ->
    generatePasswdUndo this
    Passwds.remove {'_id': @_id}
    false
}

newPasswdEntry = (tmpl) ->
  deleteCurrentUndo()
  htmlTitle = tmpl.find('#new-title')
  htmlUsername = tmpl.find('#new-username')
  htmlPass = tmpl.find('#new-password')
  encrypted = encrypt htmlPass.value
  Meteor.call 'insertPasswd',
              htmlTitle.value,
              htmlUsername.value,
              encrypted

  htmlTitle.value = ''
  htmlUsername.value = ''
  htmlPass.value = ''
  Session.set x for x in ['new-title', 'new-username', 'new-password']

  null

Template.new.events {
  'click #button-new': (ev, tmpl) ->
    newPasswdEntry tmpl
  'keyup .input-new' : (ev, tmpl) ->
    id = ev.target.getAttribute('id')
    value = ev.target.value
    if value == ''
      Session.set id
    else
      Session.set id, value

    if ev.type == 'keyup' and ev.which == 13 and allNewInputsSet()
      newPasswdEntry tmpl

    null
}

allNewInputsSet = () ->
  Session.get('passphrase')? and _.all(
    Session.get(x)? for x in ['new-title', 'new-username', 'new-password'])

Template.new.newEnabled = () ->
  allNewInputsSet()
      

Template.passwdcell.events {
  'dblclick .cell .text' : (ev, tmpl) ->
    if @value
      Session.set 'editing_cell', @_id
      Meteor.flush()
      activateInput(tmpl.find('#cell-input'))
    null

  'click .cell-link' : (ev, tmpl) ->
    Session.set 'editing_cell', @_id
    Meteor.flush()
    activateInput(tmpl.find('#cell-input'))
    null
}

Template.passwdcell.helpers {
  editing: () ->
    Session.equals 'editing_cell', @_id
  passwordClass: () ->
    if @formtype & HTMLFormTypes.password then 'password' else ''
  istextarea: () ->
    @formtype & HTMLFormTypes.textarea
  validPassphrase: () ->
    Session.get('passphrase')?
}

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
