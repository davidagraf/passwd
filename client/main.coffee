Template.hello.greeting = () ->
  "Welcome to passwd."

Template.hello.events {
  'click input' : () ->
    console.log "button clicked"
}
