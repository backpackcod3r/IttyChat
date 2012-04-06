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

# Add a 'remove' method to array to mask the unpleasantness of
# splicing
Array::remove = (e) ->
  while ((i = @indexOf(e)) > -1)
    @splice(i, 1)

#
# The Set of All Clients, and functions to operate on the set.
#
Clients =
  # The set of all clients
  clients: new Array()

  # Find a client by its socket
  addClient: (client) ->
    @clients.push(client)

  # Adds a client to the collection
  findClient: (socket) ->
    for client in @clients
      return client if socket is client.socket

  # Removes the specified client from the collection
  removeClient: (client) ->
    @clients.remove(client)

  # Notify all users (authed or not)
  notifyAll: (msg) ->
    client.notify msg for client in @clients

  # Notify all authenticated users.
  notifyAuthed: (msg) ->
    client.notify msg for client in @authedClients()

  # Notify all authenticated users, except one.
  notifyAuthedExcept: (exceptClient, msg) ->
    client.notify msg for client in @authedClients() when client isnt exceptClient

  # Return the set of all clients that are authenticated.
  authedClients: ->
    (client for client in @clients when client.isAuthenticated)

  # Returns true if the user name is in use, false otherwise.
  nameIsInUse: (name) ->
    foundIt = false
    for client in @clients
      foundIt = true if client.name? and name? and client.name.toLowerCase() is name.toLowerCase()
    foundIt

  noAuthedClients: ->
    true if @authedClients().length is 0

  # Return the number of clients (authed and unauthed)
  length: ->
    @clients.length

#
# A Client is a socket, and some associated metadata.
#   - name: The client's display name.
#   - connectedAt: When the socket first connected.
#   - isAuthenticated: True if the client has a name and is in the chat.
#   - address: The IP address of the client.
#
class Client
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
    Clients.notifyAuthedExcept this, "#{oldName} is now known as #{newName}"

  # Print a Welcome Message to the client.
  sendWelcome: ->
    @socket.write "\r\n"
    @socket.write "--------------------------------------------------------------------------"
    @socket.write "\r\n"
    @socket.write "Welcome to IttyChat!\r\n"
    @socket.write "\r\n\r\n"
    @socket.write "  To chat, type:              .connect <username>\r\n"
    @socket.write "  To see who's online, type:  .who'\r\n"
    @socket.write "  To quit, type:              .quit'\r\n"
    @socket.write "--------------------------------------------------------------------------"
    @socket.write "\r\n\r\n"

  authenticate: (name) ->
    @isAuthenticated = true
    @name = name
    @notify "Welcome to the chat, #{@name}!"
    Clients.notifyAuthedExcept this, "#{@name} has joined."

  # Write a prompt to the client (not currently used)
  prompt: ->
    @socket.write @name if @isAuthenticated
    @socket.write "> "

#
# The Chat Server
#
IttyChat =

  #
  # Handle the 'quit' command.
  #
  cmdQuit: (client) ->
    # Just call end, and let the event handler take care of cleanup.
    client.socket.end()


  #
  # Handle the 'say' command.
  #
  cmdSay: (client, msg) ->
    # TODO: Clean up input, handle non-printables, etc.
    if client.isAuthenticated
      Clients.notifyAuthed "[#{client.name}]: #{msg}" if msg? and msg.length > 0
    else
      client.notify "Please log in."

  #
  # Handle the 'connect' command.
  #
  cmdConnect: (client, name) ->
    # TODO: Reject invalid names
    if client.isAuthenticated
      client.notify "You're already logged in!"
    else
      if name.length is 0
        client.notify "Please provide a valid name."
      else if Clients.nameIsInUse(name)
        client.notify "That name is already taken!"
      else
        client.authenticate(name)

  #
  # Handle the 'nick' command.
  #
  cmdNick: (client, name) ->
    if client.isAuthenticated
      if name.length is 0
        client.notify "Please provide a valid name."
      else if client.name is name
        client.notify "Uh... OK?"
      else if (client.name.toLowerCase() is not name.toLowerCase()) and Clients.nameIsInUse(name)
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
  cmdWho: (client) ->
    if Clients.noAuthedClients()
      client.notify "No one is connected."
    else
      client.notify "The following users are connected:"
      for c in Clients.authedClients()
        client.notify "    #{c.name}"

  #
  # Handle the 'me' command
  #
  cmdMe: (client, msg) ->
    if client.isAuthenticated
      Clients.notifyAuthed("* #{client.name} #{msg}") if msg? and msg.length > 0
    else
      client.notify "You must be logged in to do that!"

  #
  # Receive input from the client, and act on it.
  #
  # TODO: This works for the simplest case, but is very fragile. It
  #       assumes all input comes from the client as a single CR/LF
  #       terminated string. What about very long input? Is it
  #       chunked? What about buffered input?
  #
  inputHandler: (client, data) ->
    rawInput = String(data).trim()

    if rawInput.length > 0
      util.log "[#{client.address}]: #{rawInput}"

      match = rawInput.match /^\.(\w*)\s*(.*)/

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
        else if command.match /^say/
          IttyChat.cmdSay client, arg
        else
          client.notify "Huh?"
      else
        IttyChat.cmdSay client, rawInput


  # Handle receiving a SIGINT or SIGKILL
  signalHandler: ->
    util.log "Cleaning up..."
    Clients.notifyAll "System going down RIGHT NOW!\r\n"
    util.log "Bye!"
    process.exit 0

  # Handle a socket 'end' event
  endHandler: (socket) ->
    client = Clients.findClient(socket)
    if client?
      Clients.removeClient client
      if client.isAuthenticated
        Clients.notifyAuthedExcept client, "#{client.name} has left the chat"
      util.log "Disconnect from #{client} [c:#{Clients.length()}]"


  clientListener: (socket) ->
    client = new Client(socket)
    Clients.addClient(client)

    util.log "Connection from #{client} [c:#{Clients.length()}]"

    client.sendWelcome()

    socket.on 'data', (data) ->
      IttyChat.inputHandler(client, data)

    socket.on 'end', ->
      IttyChat.endHandler(socket)

#
# Main
#

process.on 'SIGINT', IttyChat.signalHandler
process.on 'SIGKILL', IttyChat.signalHandler

args = process.argv.splice(2)

if args.length < 1 or args.length > 2
  console.log "Usage: coffee ittychat.coffee [-l] <port>"

#
# See if we want to bind to localhost only
#
localOnly = false
for arg in args
  localOnly = true if arg is "-l"

port = parseInt args.pop()

if port > 1024
  server = net.createServer IttyChat.clientListener

  # TODO: IPv6, etc.
  if localOnly
    addr = '127.0.0.1'
  else
    addr = '0.0.0.0'

  server.listen port, addr, ->
    util.log "Now listening on #{server.address().address}:#{server.address().port}"


else
  console.log "Port must be > 1024"
  process.exit 1