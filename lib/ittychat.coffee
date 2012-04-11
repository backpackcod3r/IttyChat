#
# IttyChat: A (very!) simple Node.js chat server, written in
# CoffeeScript
#
#
# Copyright (c) 2012 Seth J. Morabito <web@loomcom.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

util = require 'util'
net = require 'net'
fs = require 'fs'
path = require 'path'

# Max string length of 1024 characters (UTF-8, so they may in fact
# be multibyte)
MAX_INPUT_LENGTH: 1024

MAX_NAME_LENGTH: 16

#
# Add a 'remove' method to array to mask the unpleasantness of
# splicing
#
Array::remove = (e) ->
  while ((i = @indexOf(e)) > -1)
    @splice(i, 1)

#
# A Client is a socket, and some associated metadata.
#   - name: The client's display name.
#   - connectedAt: When the socket first connected.
#   - isAuthenticated: True if the client has a name and is in the chat.
#   - address: The IP address of the client.
#
class Client

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


  #
  # Instance Properties
  #

  constructor: (@socket) ->
    @name = null
    @connectedAt = Date.now()
    @isAuthenticated = false
    @address = @socket.remoteAddress

  # Writes a message to the client.
  notify: (msg) ->
    @socket.write "#{msg}\r\n"

  # Return a human-readable representation of the client
  # (for logging, for example)
  toString: ->
    "[name: #{@name}, address: #{@address}, connectedAt: #{@connectedAt}]"

  # Change a user's name
  changeName: (newName) ->
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
    fs.readFile name, (err, data) ->
      if err?
        if err.code is 'ENOENT'
          util.log "#{name} was requested, but is missing (or unreadable)"
          client.notify defaultText if defaultText?
        else
          raise err
      else
        util.log "Sending file #{fileName}"
        client.notify String(data)

  authenticate: (name) ->
    @isAuthenticated = true
    @name = name
    @notify "Welcome to the chat, #{@name}!"
    @sendMotd()
    @notifyOthers "#{@name} has joined."

  # Write a prompt to the client (not currently used)
  prompt: ->
    @socket.write @name if @isAuthenticated
    @socket.write "> "

class IttyChat
  #
  # Handle the 'quit' command.
  #
  @cmdQuit: (client) ->
    # Just call end, and let the event handler take care of cleanup.
    client.socket.end()

  #
  # Handle the 'help' command.
  #
  @cmdHelp: (client) ->
    client.sendHelp()

  #
  # Handle the 'motd' command.
  #
  @cmdMotd: (client) ->
    client.sendMotd()

  #
  # Handle the 'say' command.
  #
  @cmdSay: (client, msg) ->
    if client.isAuthenticated
      Client.notifyAuthed "[#{client.name}]: #{msg}" if msg? and msg.length > 0
    else
      client.notify "Please log in."

  #
  # Returns true  if the name is invalid.
  #
  @isInvalidName: (name) ->
    name.search(/[^\w-|]+/g) > 0 or
      name.length > @MAX_NAME_LENGTH or
      name.length is 0

  #
  # Handle the 'connect' command.
  #
  @cmdConnect: (client, name) ->
    if client.isAuthenticated
      client.notify "You're already logged in!"
    else
      if @isInvalidName(name)
        client.notify "That is not a valid name, sorry."
      else if Client.nameIsInUse(name)
        client.notify "That name is already taken!"
      else
        client.authenticate(name)

  #
  # Handle the 'nick' command.
  #
  @cmdNick: (client, name) ->
    if client.isAuthenticated
      if @isInvalidName(name)
        client.notify "That is not a valid name, sorry."
      else if client.name is name
        client.notify "Uh... OK?"
      else if (client.name.toLowerCase() is not name.toLowerCase()) and Client.nameIsInUse(name)
        # The 'toLowerCase' check is a speciaql case to bypass
        # "name is in use" check when a user simply wants to
        # change capitalization of his or her own nick, i.e.,
        # "joebob" to "JoeBob",
        client.notify "That name is already taken!"
      else
        client.changeName name
    else
      client.notify "Please log in (with .connect <username>) first."

  #
  # Handle the 'who' command.
  #
  @cmdWho: (client) ->
    if Client.noAuthedClients()
      client.notify "No one is connected."
    else
      client.notify "The following users are connected:"
      for c in Client.authedClients()
        client.notify "    #{c.name}"

  #
  # Handle the 'me' command
  #
  @cmdMe: (client, msg) ->
    if client.isAuthenticated
      Client.notifyAuthed("* #{client.name} #{msg}") if msg? and msg.length > 0
    else
      client.notify "You must be logged in to do that!"

  #
  # Take raw data received from a socket and scrub it
  # of non-printable characters. Returns the scrubbed string.
  #
  @cleanInput: (str) ->
    # Remove leading and trailing whitespace, and
    # truncate to our max_length
    cleanedInput = str.substring(0, @MAX_INPUT_LENGTH)

    # Remove all control characters. These are conveniently located in
    # the first two pages of the ASCII/UTF8 character space
    cleanedInput = cleanedInput.replace /[\u0000-\u001f\u007f]/g, ''

    cleanedInput.trim()

  #
  # Receive input from the client, and act on it.
  #
  # TODO: This works for the simplest case, but is very fragile. It
  #       assumes all input comes from the client as a single CR/LF
  #       terminated string. What about very long input? Is it
  #       chunked? What about buffered input?
  #
  @inputHandler: (client, data) ->
    cleanedInput = IttyChat.cleanInput(data)

    if cleanedInput.length > 0
      util.log "[#{client.address}]: #{cleanedInput}"

      match = cleanedInput.match /^\.(\w*)\s*(.*)/

      if match?
        command = match[1]
        arg = match[2].trim()

        if command.match /^quit/
          IttyChat.cmdQuit client
        else if command.match /^connect/
          IttyChat.cmdConnect client, arg
        else if command.match /^nick/
          IttyChat.cmdNick(client, arg);
        else if command.match /^who/
          IttyChat.cmdWho client
        else if command.match /^me/
          IttyChat.cmdMe client, arg
        else if command.match /^help/
          IttyChat.cmdHelp client
        else if command.match /^motd/
          IttyChat.cmdMotd client
        else if command.match /^say/
          IttyChat.cmdSay client, arg
        else
          client.notify "Huh?"

      else
        IttyChat.cmdSay client, cleanedInput

  # Handle receiving a SIGINT or SIGKILL
  @signalHandler: ->
    util.log "Cleaning up..."
    Client.notifyAll "System going down RIGHT NOW!\r\n"
    util.log "Bye!"
    process.exit 0

  # Handle a socket 'end' event
  @endHandler: (socket) ->
    client = Client.findClient(socket)
    if client?
      Client.removeClient client
      if client.isAuthenticated
        client.notifyOthers "#{client.name} has left the chat"
      util.log "Disconnect from #{client} [c:#{Client.count()}]"


  @clientListener: (socket) ->
    # Handle all strings internally as UTF-8.
    socket.setEncoding('utf8')

    client = new Client(socket)
    Client.addClient(client)

    util.log "Connection from #{client} [c:#{Client.count()}]"

    client.sendWelcome()

    socket.on 'data', (data) ->
      IttyChat.inputHandler(client, data)

    socket.on 'end', ->
      IttyChat.endHandler(socket)

  @createServer: (address, port) ->
    process.on 'SIGINT', @signalHandler
    process.on 'SIGKILL', @signalHandler
    server = net.createServer @clientListener
    server.listen port, address, ->
      util.log "Now listening on #{server.address().address}:#{server.address().port}"


module.exports = IttyChat
