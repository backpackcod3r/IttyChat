#
# Copyright (c) 2012 Seth J. Morabito <web@loomcom.com>
#
#
# A Client is a socket, and some associated metadata.
#   - user: If the client is authenticated, it will be backed
#     by a User model loaded from the database.
#   - connectedAt: When the socket first connected.
#   - address: The IP address of the client.
#

fs     = require 'fs'
util   = require 'util'
path   = require 'path'
bcrypt = require 'bcrypt'
models = require __dirname + '/models'
config = require __dirname + '/../config'

#
# Add a 'remove' method to array to mask the unpleasantness of
# splicing
#
Array::remove = (e) ->
  while ((i = @indexOf(e)) > -1)
    @splice(i, 1)

commands = (() ->
  quit: (client, args) ->
    client.notify "Goodbye!"
    client.socket.end()

  register: (client, args) =>
    if args.length == 3
      client.register args[0], args[1], args[2], (error) ->
        client.notify error if error?
    else
      client.notify "Try: register <name> <password> <email>"

  connect: (client, args) =>
    if args.length == 2
      client.authenticate args[0], args[1], (error, user) ->
        client.notify error if error?
    else
      client.notify "Try: connect <name> <password>"

  nick: (client, args) =>
    if args.length == 1
      client.changeName args[0], (error, user) ->
        client.notify error if error?
    else
      client.notify "Try: nick <newname>"

  who: (client, args) =>
    if Client.authedClients().length is 0
      client.notify "No one is connected."
    else
      client.notify "The following users are connected:"
      for c in Client.authedClients()
        client.notify "    #{c.name()}"

  emote: (client, args) =>
    msg = args[0]

    if client.isAuthenticated()
      Client.notifyAuthed("#{client.name()} #{msg}") if msg? and msg.length > 0
    else
      client.notify "You must be logged in to do that!"

  say: (client, args) =>
    msg = args[0]

    if client.isAuthenticated()
      Client.notifyAuthed "#{client.name()} says \"#{msg}\"" if msg? and msg.length > 0
    else
      client.notify "Please log in."

  help: (client, args) =>
    client.sendFile "help.txt", "Help not available"

  motd: (client, args) =>
    client.sendFile "motd.txt"
)()


class Client

  @MAX_NAME_LENGTH: 16

  #
  # Returns a command in the form [verb, args], where the args is an array
  # of zero or more command arguments.
  #
  # TODO: This does not account for quoted args like: 'foo "bar baz" quux'. It should.
  #
  parseCommand: (input) =>
    config.logger.info "[#{@address}]: #{input}"

    # In keeping with tradition, there are two 'special cases',
    # the verb " (single quotes) and the verb : (colon). These will
    # be mapped to 'say' and 'emote', respectively.

    if input[0] == "\""
      ["say", [input[1..-1]]]
    else if input[0] == ":"
      ["emote", [input[1..-1]]]
    else
      # Attempt to match at least one word (the verb), followed
      # by an optional whitespace and "the rest", which is split into
      # words.
      match = input.match /^\s*([^\s]+)\s*(.*)/
      if match
        command = match[1]
        args = (match[2] and match[2].split(/\s/)) or []
        [command, args]
      else
        [null,[]]
  #
  # Receive input from the client, and act on it.
  #
  parseAndExecute: (input) =>
    command = @parseCommand(input)
    verb = command[0]
    args = command[1]

    f = commands[verb]

    if f
      f(@, args)
    else
      @notify "Huh?"

  #
  # Class properties
  #

  # The set of all clients currently connected to the server.
  @clients: new Array()

  # Find a client by its socket
  @addClient: (client) ->
    @clients.push(client)

  # Adds a client to the collection
  @findClient: (socket) ->
    for client in @clients
      return client if socket is client.socket

  # Removes the specified client from the collection
  @removeClient: (client) ->
    @clients.remove(client)

  # Notify all users (authed or not)
  @notifyAll: (msg) ->
    client.notify msg for client in @clients

  # Notify all authenticated users.
  @notifyAuthed: (msg) ->
    client.notify msg for client in @authedClients()

  # Return the set of all clients that are authenticated.
  @authedClients: ->
    (client for client in @clients when client.isAuthenticated())

  # Return the number of clients (authed and unauthed)
  @count: ->
    @clients.length

  # Reset the container.
  @resetAll = ->
    client.socket.close() for client in @clients
    @clients = new Array()

  # Returns true if any client is connected and authenticated
  # with the given name.
  @isConnected = (name) ->
    allMatching = (client for client in Client.authedClients() when client.name() == name)
    allMatching.length > 0

  #
  # Instance Properties
  #

  constructor: (@socket) ->
    @connectedAt = Date.now()
    @address = @socket.remoteAddress
    # Allow dependency injection
    @fs = fs

  # Writes a message to the client.
  notify: (msg) ->
    @socket.write "#{msg}\r\n"

  # Returns true if the client has been authenticated and has loaded
  # a User from the database.
  isAuthenticated: () =>
    @user?

  # Return a human-readable representation of the client
  # (for logging, for example)
  toString: ->
    "[name: #{@name()}, address: #{@address}, connectedAt: #{@connectedAt}]"

  # Print a Welcome Message to the client.
  sendWelcome: ->
    @sendFile "welcome.txt", "Welcome to IttyChat!\r\nPlease configure your welcome message in welcome.txt!"

  # Returns the user's name
  name: ->
    @user.name if @user?

  # Notify all authenticated users, except this one.
  notifyOthers: (msg) ->
    client.notify msg for client in Client.authedClients() when client isnt this

  # Returns true if the name is valid, false otherwise.
  isValidName: (name) ->
    name.search(/[^\w-|]+/g) is -1 and
      name.length <= Client.MAX_NAME_LENGTH and
      name.length > 0

  # Send a local file to output
  sendFile: (fileName, defaultText) ->
    # TODO: Clearly, this has huge potential for security issues.
    #       Make sure that the file we're sending is relative to the
    #       current working directory, and has no '..' elements.
    client = this
    name = path.join(__dirname, '..', 'etc', fileName)
    @fs.readFile name, (err, data) ->
      if err?
        if err.code is 'ENOENT'
          config.logger.warn "#{name} was requested, but is missing (or unreadable)"
          client.notify defaultText if defaultText?
        else
          throw err
      else
        config.logger.info "Sending file #{fileName}"
        client.notify String(data)

  #
  # Register a new user
  #
  register: (name, password, email, callback) =>
    if !name || !password || !email
      callback "Username, password, and email are required"
    else
      if @isValidName(name)
        # TODO: Verify password is 6 chars or more.
        # TODO: Email new user.
        salt = bcrypt.genSaltSync()
        hash = bcrypt.hashSync(password, salt)
        config.logger.info "Creating New User: #{name}, [#{hash}], #{email}"
        models.User.find(where: {name: name}).success (user) =>
          if user
            callback "A user with that name already exists."
          else
            user = models.User.build({name: name, cryptedPassword: hash, email: email})
            user.save().success (user) =>
              @notify "User created! Welcome!"
              @authenticate name, password, callback
      else
        callback "That is not a valid name, sorry."


  #
  # Authenticate a client by name and password.
  #
  authenticate: (name, password, callback) =>
    if @isAuthenticated()
      callback "You're already logged in!"
    else if Client.isConnected(name)
      callback 'That user is already connected!'
    else if !password
      callback "Password is required."
    else
      models.User.find(where: {name: name}).success (user) =>
        if user
          if bcrypt.compareSync(password, user.cryptedPassword)
            @user = user
            @notify "Welcome to the chat, #{@name()}!"
            @notifyOthers "#{@name()} has joined."
            @sendFile "motd.txt"
            callback null, @
          else
            callback "Incorrect password"
        else
          callback "No such user"

  # Change a user's name
  changeName: (newName, callback) =>
    if not @isAuthenticated()
      callback "Please log in (with .connect <username>) first.", @
    else if not @isValidName(newName)
      callback "That is not a valid name, sorry.", @
    else
      models.User.isNameAvailable newName, (isAvailable) =>
        if not isAvailable and @name().toLowerCase() isnt newName.toLowerCase()
          # The 'toLowerCase' check is a special case to bypass
          # "name is in use" check when a user simply wants to
          # change capitalization of his or her own nick, i.e.,
          # "joebob" to "JoeBob",
          callback 'That name is already taken!', @
        else
          oldName = @name()
          @user.updateAttributes(name: newName).success (user) =>
            @notify "Changing user name to #{newName}"
            @notifyOthers "#{oldName} is now known as #{newName}"
            callback null, @


module.exports = Client