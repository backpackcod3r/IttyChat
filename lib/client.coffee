#
# Copyright (c) 2012 Seth J. Morabito <web@loomcom.com>
#
#
# A Client is a socket, and some associated metadata.
#   - name: The client's display name.
#   - connectedAt: When the socket first connected.
#   - isAuthenticated: True if the client has a name and is in the chat.
#   - address: The IP address of the client.
#

fs   = require 'fs'
util = require 'util'
path = require 'path'

#
# Add a 'remove' method to array to mask the unpleasantness of
# splicing
#
Array::remove = (e) ->
  while ((i = @indexOf(e)) > -1)
    @splice(i, 1)

class Client

  @MAX_NAME_LENGTH: 16

  #
  # Class properties
  #

  # The set of all clients
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
    (client for client in @clients when client.isAuthenticated)

  # Returns true if the user name is in use, false otherwise.
  @nameIsInUse: (name) ->
    foundIt = false
    for client in @clients
      foundIt = true if client.name? and name? and client.name.toLowerCase() is name.toLowerCase()
    foundIt

  @noAuthedClients: ->
    true if @authedClients().length is 0

  # Return the number of clients (authed and unauthed)
  @count: ->
    @clients.length

  # Reset the container.
  @resetAll = ->
    @clients = new Array()

  #
  # Instance Properties
  #

  constructor: (@socket) ->
    @name = null
    @connectedAt = Date.now()
    @isAuthenticated = false
    @address = @socket.remoteAddress
    # Allow dependency injection
    @fs = fs

  # Writes a message to the client.
  notify: (msg) ->
    @socket.write "#{msg}\r\n"

  # Return a human-readable representation of the client
  # (for logging, for example)
  toString: ->
    "[name: #{@name}, address: #{@address}, connectedAt: #{@connectedAt}]"

  # Change a user's name
  changeName: (newName) ->
    if not @isAuthenticated
      throw "Please log in (with .connect <username>) first."
    else if not @isValidName(newName)
      throw "That is not a valid name, sorry."
    else if Client.nameIsInUse(newName) and not (@name.toLowerCase() is newName.toLowerCase())
      # The 'toLowerCase' check is a speciaql case to bypass
      # "name is in use" check when a user simply wants to
      # change capitalization of his or her own nick, i.e.,
      # "joebob" to "JoeBob",
      throw "That name is already taken!"
    else
      oldName = @name
      @name = newName
      @notify "Changing user name to #{@name}"
      @notifyOthers "#{oldName} is now known as #{newName}"

  # Print a Welcome Message to the client.
  sendWelcome: ->
    @sendFile "welcome.txt", "Welcome to IttyChat!\r\nPlease configure your welcome message in welcome.txt!"

  # Notify all authenticated users, except this one.
  notifyOthers: (msg) ->
    client.notify msg for client in Client.authedClients() when client isnt this

  # Returns true  if the name is invalid.
  isValidName: (name) ->
    name.search(/[^\w-|]+/g) is -1 and
      name.length <= Client.MAX_NAME_LENGTH and
      name.length > 0

  # Print the help file
  sendHelp: ->
    @sendFile "help.txt", "Help not available"

  # Print the Message of the Day
  sendMotd: ->
    @sendFile "motd.txt"

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
          util.log "#{name} was requested, but is missing (or unreadable)"
          client.notify defaultText if defaultText?
        else
          throw err
      else
        util.log "Sending file #{fileName}"
        client.notify String(data)

  authenticate: (name) ->
    if @isAuthenticated
      throw "You're already logged in!"
    else if Client.nameIsInUse name
      throw "That name is already taken!"
    else if @isValidName name
      @isAuthenticated = true
      @name = name
      @notify "Welcome to the chat, #{@name}!"
      @sendMotd()
      @notifyOthers "#{@name} has joined."
    else
      throw "That is not a valid name, sorry."

  # Write a prompt to the client (not currently used)
  prompt: ->
    @socket.write @name if @isAuthenticated
    @socket.write "> "

module.exports = Client