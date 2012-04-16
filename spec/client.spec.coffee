Client = require('../lib/client')
fs = require('fs')
path = require('path')

#
# A stub for net.Socket, so we can inspect calls.
#
class SocketStub
  constructor: (@remoteAddress) ->
    @bytesWritten = 0
    @notifications = new Array()

  write: (string) ->
    @bytesWritten += string.length
    @notifications.push string

#
# - Get an instance of a stub socket (for convenience)
# - Reset client container.
#
beforeEach ->
  @authedSocket = new SocketStub("192.168.1.1")
  @unauthedSocket = new SocketStub("192.168.1.2")
  @authedClient = new Client(@authedSocket)
  @authedClient.isAuthenticated = true
  @unauthedClient = new Client(@unauthedSocket)

  spyOn(fs, 'readFile').andReturn('')

  # Add a convenience function to make a bunch of clients
  @addTestClients = (count) ->
    for num in [0...count]
      Client.addClient(new Client(new SocketStub("10.1.2.#{num}")))

  # Add custom matchers
  @addMatchers

    toBeNotified: (msg) ->
      messageReceived = false
      for message in @actual.socket.notifications
        if msg instanceof RegExp
          messageReceived = true if message.match(msg)
        else
          messageReceived = true if message is msg

      if not messageReceived
        @message = ->
          ["Expected client #{@actual} to have received notification `#{msg}', but it did not",
           "Expected client #{@actual} not to have received notification `#{msg}', but it did"]

      messageReceived

    toBeAuthenticatedWith: (name) ->
      result = @actual.isAuthenticated and @actual.name is name
      if not result
        @message = ->
          ["Expected client #{@actual} to be authenticated with name `#{name}', " +
            "but was: authenticated=#{@actual.isAuthenticated}, name=#{@actual.name}",
           "Expected client #{@actual} not to be authenticated with name `#{name}', " +
            "but was: authenticated=#{@actual.isAuthenticated}, name=#{@actual.name}"]
      result

  # Then reset the client store
  Client.resetAll()


describe "The Client Collection", ->

  it "should notify all users with notifyAll", ->
    Client.addClient @authedClient
    Client.addClient @unauthedClient

    Client.notifyAll "A Notification"

    expect(@authedClient).toBeNotified "A Notification\r\n"
    expect(@unauthedClient).toBeNotified "A Notification\r\n"

  it "should notify only logged in users with notifyAuthed", ->
    Client.addClient @authedClient
    Client.addClient @unauthedClient

    Client.notifyAuthed "A Notification"

    expect(@authedClient).toBeNotified "A Notification\r\n"
    expect(@unauthedClient).not.toBeNotified "A Notification\r\n"

  it "should be able to find a client by socket", ->
    Client.addClient(@authedClient)
    expect(Client.findClient(@authedSocket)).toEqual @authedClient

  it "should start with no clients", ->
    expect(Client.count()).toEqual 0

  it "should increment count when adding a client", ->
    oldCount = Client.count()
    Client.addClient(@unauthedClient)
    expect(Client.count()).toEqual oldCount + 1

  it "should decrement count when removing a client", ->
    Client.addClient(@authedClient)
    oldCount = Client.count()
    Client.removeClient(@authedClient)
    expect(Client.count()).toEqual oldCount - 1

  it "should give access to the set of authed clients", ->
    Client.addClient(@unauthedClient)
    Client.addClient(@authedClient)
    expect(Client.count()).toEqual 2
    expect(Client.authedClients()).toEqual [@authedClient]

  it "should be able to tell whether a name is in use", ->
    Client.addClient(@authedClient)
    expect(Client.nameIsInUse("JoeBobBriggs")).toBeFalsy()
    @authedClient.name = "JoeBobBriggs"
    expect(Client.nameIsInUse("JoeBobBriggs")).toBeTruthy()

  it "should ignore case when checking user names", ->
    Client.addClient(@authedClient)
    expect(Client.nameIsInUse("joebobbriggs")).toBeFalsy()
    @authedClient.name = "JOEBOBBRIGGS"
    expect(Client.nameIsInUse("joebobbriggs")).toBeTruthy()

  it "should be able to tell if there are no authed clients", ->
    Client.addClient(@unauthedClient)
    expect(Client.noAuthedClients()).toBeTruthy()
    Client.addClient(@authedClient)
    expect(Client.noAuthedClients()).toBeFalsy()

  it "should be able to reset itself", ->
    Client.addClient(@unauthedClient)
    expect(Client.count()).toEqual 1
    expect(Client.clients[0]).toEqual @unauthedClient

    Client.resetAll()

    expect(Client.count()).toEqual 0
    expect(Client.clients[0]).toBeUndefined


describe "A Client Instance", ->

  it "should get socket's remote address", ->
    expect(@unauthedClient.address).toEqual @unauthedSocket.remoteAddress

  it "should not be authenticated when created", ->
    c = new Client(new SocketStub("1.2.3.4"))
    expect(c.isAuthenticated).toBeFalsy()

  it "should write to client socket", ->
    @unauthedClient.notify("1234")
    expect(@unauthedClient).toBeNotified "1234\r\n"

  it "should respond to toString", ->
    expect(@unauthedClient.toString()).toMatch /address/
    expect(@unauthedClient.toString()).toMatch /name/
    expect(@unauthedClient.toString()).toMatch /connectedAt/

  it "should be able to authenticate", ->
    expect(@unauthedClient.isAuthenticated).toBeFalsy()
    @unauthedClient.authenticate("JoeBobBriggs")
    expect(@unauthedClient.isAuthenticated).toBeTruthy()

  it "should not allow double authentication", ->
    expect(@unauthedClient.isAuthenticated).toBeFalsy()
    @unauthedClient.authenticate("JoeBobBriggs")
    c = @unauthedClient
    expect(-> c.authenticate("JoeBobBriggs")).toThrow "You're already logged in!"

  it "should not allow authentication with an invalid name", ->
    expect(@unauthedClient.isAuthenticated).toBeFalsy()
    c = @unauthedClient
    expect(-> c.authenticate("Joe Bob Briggs")).toThrow "That is not a valid name, sorry."

  it "should be able to send motd file", ->
    @authedClient.sendMotd()
    expect(fs.readFile).toHaveBeenCalled()
    expect(fs.readFile.mostRecentCall.args).toMatch /etc\/motd.txt/

  it "should be able to send welcome file", ->
    @authedClient.sendWelcome()
    expect(fs.readFile).toHaveBeenCalled()
    expect(fs.readFile.mostRecentCall.args).toMatch /etc\/welcome.txt/

  it "should be able to notify others", ->
    @addTestClients 5

    # Make everybody authenticated
    for client, i in Client.clients
      client.authenticate("client_#{i}")

    Client.clients[0].notifyOthers "This is a message for others"

    # Client who sent the notification should not be notified
    expect(Client.clients[0]).not.toBeNotified /This is a message for others/

    # Other clients should have been notified
    for client in Client.clients[1..-1]
      expect(client).toBeNotified /This is a message for others/

  it "should send motd when authenticated", ->
    @unauthedClient.authenticate("JoeBobBriggs")
    expect(fs.readFile).toHaveBeenCalled()
    expect(fs.readFile.mostRecentCall.args).toMatch /etc\/motd.txt/

  it "should send help file if asked", ->
    @unauthedClient.sendHelp()
    expect(fs.readFile).toHaveBeenCalled()
    expect(fs.readFile.mostRecentCall.args).toMatch /etc\/help.txt/

  it "should be able to change its name", ->
    @unauthedClient.authenticate "JoeBobBriggs"
    @unauthedClient.changeName "SantaClaus"
    expect(@unauthedClient.name).toEqual "SantaClaus"
    expect(@unauthedClient).toBeAuthenticatedWith "SantaClaus"

  it "should not allow changing to an invalid name", ->
    @unauthedClient.authenticate "JoeBobBriggs"
    c = @unauthedClient
    expect(-> c.changeName("Santa Claus")).toThrow "That is not a valid name, sorry."
    expect(@unauthedClient).toBeAuthenticatedWith "JoeBobBriggs"

  it "should not allow changing to a name that is already in use", ->
    @addTestClients 2
    joe = Client.clients[0]
    bob = Client.clients[1]
    joe.authenticate "Joe"
    bob.authenticate "Bob"
    expect(-> bob.changeName("joe")).toThrow "That name is already taken!"
    expect(bob).toBeAuthenticatedWith "Bob"

  it "should notify self when authenticating", ->
    @unauthedClient.authenticate "JoeBobBriggs"
    expect(@unauthedClient).toBeNotified /welcome to the chat, joebobbriggs/i

  it "should not notify unauthed users when authenticating", ->
    @addTestClients 5

    joe = Client.clients[0]

    joe.authenticate "JoeBobBriggs"

    # Nobody else should be told,
    for client in Client.clients[1..-1]
      expect(client).not.toBeNotified /joebobbriggs has joined/i

  it "should notify authed users when authenticating", ->
    @addTestClients 5

    joe = Client.clients[0]
    alice = Client.clients[1]
    others = Client.clients[2..-1]

    joe.authenticate "JoeBobBriggs"
    alice.authenticate "Alice"

    expect(joe).toBeNotified /welcome to the chat, joebobbriggs/i
    expect(alice).toBeNotified /welcome to the chat, alice/i
    expect(joe).toBeNotified /alice has joined/i

    for client in others
      expect(client.socket.notifications.length).toEqual 0

  it "should notify self when changing names", ->
    @unauthedClient.authenticate "OldName"
    @unauthedClient.changeName "JoeBobBriggs"

    expect(@unauthedClient).toBeNotified /changing user name to joebobbriggs/i

  it "should not validate names over 16 characters", ->
    expect(@authedClient.isValidName('foobarfoobarfoob')).toBeTruthy()
    expect(@authedClient.isValidName('foobarfoobarfooba')).toBeFalsy()

  it "should not validate names with spaces", ->
    expect(@authedClient.isValidName('foo bar')).toBeFalsy()

  it "should not validate empty names", ->
    expect(@authedClient.isValidName('')).toBeFalsy()

  it "should validate names with underscores, dashes, and pipes", ->
    expect(@authedClient.isValidName('foo-bar')).toBeTruthy()
    expect(@authedClient.isValidName('foo_bar')).toBeTruthy()
    expect(@authedClient.isValidName('foo|bar')).toBeTruthy()

  it "should not notify unauthed users when changing names", ->
    @addTestClients 5

    joe = Client.clients[0]

    joe.authenticate "OldName"
    joe.changeName "JoeBobBriggs"

    # Nobody else should be told,
    for client in Client.clients[1..-1]
      expect(client).not.toBeNotified /oldname is now known as joebobbriggs/i

  it "should notify authed users when changing names", ->
    @addTestClients 5

    joe = Client.clients[0]
    alice = Client.clients[1]
    others = Client.clients[2..-1]

    joe.authenticate "OldName"
    alice.authenticate "Alice"
    joe.changeName "JoeBobBriggs"

    expect(joe.socket.notifications.length).toEqual 3
    expect(alice.socket.notifications.length).toEqual 2

    for client in others
      expect(client.socket.notifications.length).toEqual 0

