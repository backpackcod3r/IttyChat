/****************************************************************************
 * 
 * IttyChat: A (very!) simple Node.js chat server
 *
 *
 * Copyright (c) 2012 Seth J. Morabito <web@loomcom.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * 
 ***************************************************************************/

var util = require('util');
var net = require('net');

var Clients = {

    // The set of all clients
    clients: [],

    /*
     * Find a client by its socket.
     */
    findClient: function(socket) {
        for (var i in this.clients) {
            if (this.clients[i].socket === socket) {
                return this.clients[i];
            }
        }
    },

    /*
     * Adds a client to the collection.
     */
    addClient: function(client) {
        this.clients.push(client);
    },

    /*
     * Removes the specified client from the collection.
     */
    removeClient: function(client) {
        var idx = this.clients.indexOf(client);
        if (idx >= 0) {
            this.clients.splice(idx, 1);
        }
    },

    /*
     * Notify all users (authed or not)
     */
    notifyAll: function(msg) {
        this.clients.forEach(function(client) {
            client.notify(msg);
        });
    },

    /*
     * Notify all authenticated users.
     */
    notifyAuthed: function(msg) {
        this.authedClients().forEach(function(client) {
            client.notify(msg);
        });
    },

    /*
     * Notify all authenticated users EXCEPT one.
     */
    notifyAuthedExcept: function(exceptClient, msg) {
        this.authedClients().forEach(function(client) {
            if (client !== exceptClient) {
                client.notify(msg);
            }
        });
    },

    /*
     * Return the set of all clients that are authenticated.
     */
    authedClients: function() {
        var authedClients = [];
        this.clients.forEach(function(client) {
            if (client.isAuthenticated) {
                authedClients.push(client);
            }
        });
        return authedClients;
    },

    /*
     * Returns true if the user name is in use, false otherwise.
     */
    nameIsInUse: function(name) {
        var foundIt = false
        this.clients.forEach(function(client) {
            if (client.name !== null && client.name !== undefined &&
                name !== null && name !== undefined) {
                if (client.name.toLowerCase() === name.toLowerCase()) { foundIt = true; }
            }
        });
        return foundIt;
    },

    /*
     * Returns the number of clients.
     */
    length: function() { return this.clients.length }
};

/*
 * A Client is a socket, and some associated metadata.
 *   - name: The client's display name.
 *   - connectedAt: When the socket first connected.
 *   - isAuthenticated: True if the client has a name and is in the chat.
 *   - address: The IP address of the client.
 */
var Client = function(socket) {
    this.socket = socket;
    this.name = null;
    this.connectedAt = Date.now();
    this.isAuthenticated = false;
    this.address = socket.remoteAddress;
};

/*
 * Writes a message to the client.
 */
Client.prototype.notify = function(msg) {
    this.socket.write(msg + "\r\n");
};

/*
 * Return a human-readable representation of the client
 * (for logging, for example)
 */
Client.prototype.toString = function() {
    return("[name: " + this.name +
           ", address: " + this.address +
           ", connectedAt: " + this.connectedAt +
           "]");
};

/*
 * Write a Welcome message to the client.
 */
Client.prototype.sendWelcome = function() {
    this.socket.write("\r\n");
    this.socket.write("--------------------------------------------------------------------------");
    this.socket.write("\r\n");
    this.socket.write("Welcome to IttyChat!\r\n");
    this.socket.write("\r\n\r\n");
    this.socket.write("  To chat, type:              .connect <username>\r\n");
    this.socket.write("  To see who's online, type:  .who'\r\n");
    this.socket.write("  To quit, type:              .quit'\r\n");
    this.socket.write("--------------------------------------------------------------------------");
    this.socket.write("\r\n\r\n");
};

/*
 * Write a prompt to the client (not currently used)
 */
Client.prototype.prompt = function() {
    if (this.isAuthenticated) {
        this.socket.write(this.name);
    }
    this.socket.write("> ");
};

IttyChat = {

    /*
     * Handle the '.quit' command.
     */
    cmdQuit: function(client) {
        // Just call end, and let the 'end' event handler take
        // care of cleanup.
        client.socket.end();
    },

    /*
     * Handle the '.say' command.
     */
    cmdSay: function(client, msg) {
        // TODO: Clean up the message. Strip control characters, etc.
        if (client.isAuthenticated) {
            Clients.notifyAuthed("[" + client.name + "]: " + msg);
        } else {
            client.notify("Please log in.");
        }
    },

    /*
     * Handle the '.connect' command.
     */
    cmdConnect: function(client, name) {
        // TODO: Clean and normalize user name, or reject malformed names.
        if (!client.isAuthenticated) {
            if (name.length === 0) {
                client.notify("Please provide a valid name.");
            } else if (Clients.nameIsInUse(name)) {
                client.notify("That name is already taken!");
            } else {
                client.name = name;
                client.isAuthenticated = true;
                client.notify("Welcome to the chat, " + name + "!");
                Clients.notifyAuthedExcept(client, client.name + " has joined.");
            }
        } else {
            client.notify("You're already logged in! Type /q to quit.");
        }
    },


    /*
     * Handle the '.nick' command.
     */
    cmdNick: function(client, name) {
        // TODO: Clean and normalize user name, or reject malformed names.
        //       Forbid names already connected.

        var oldName;
        if (client.isAuthenticated) {
            if (name.length === 0) {
                client.notify("Please provide a valid name.");
            } else if (client.name === name) {
                client.notify("Uh... OK?");
            } else if ((client.name.toLowerCase() !== name.toLowerCase()) &&
                       Clients.nameIsInUse(name)) {
                // The 'toLowerCase' check is a speciaql case to bypass
                // "name is in use" check when a user simply wants to
                // change capitalization of his or her own nick, i.e.,
                // "joebob" to "JoeBob",
                client.notify("That name is already taken!");
            } else {
                oldName = client.name;
                client.name = name;
                client.notify("Changing user name to " + client.name);
                Clients.notifyAuthedExcept(client, oldName + " is now known as " + client.name);
            }
        } else {
            client.notify("Please log in (with .connect <username>) first.");
        }
    },

    /*
     * Handle the '.who' command.
     */
    cmdWho: function(client) {
        if (Clients.authedClients().length === 0) {
            client.notify("No one is connected.");
        } else {
            client.notify("The following users are connected:");
            Clients.authedClients().forEach(function(c) {
                client.notify("    " + c.name);
            });
        }
    },

    /*
     * Handle the '.me' command.
     */
    cmdMe: function(client, msg) {
        if (client.isAuthenticated) {
            Clients.notifyAuthed("* " + client.name + " " + msg);
        } else {
            client.notify("You must be logged in to do that!");
        }
    },

    /*
     * Receive input from the client, and act on it.
     *
     * TODO: This works for the simplest case, but is very fragile. It
     *       assumes all input comes from the client as a single CR/LF
     *       terminated string. What about very long input? Is it
     *       chunked? What about buffered input?
     */
    inputHandler: function(client, data) {
        var rawInput, arg, match, command;

        rawInput = String(data).trim();

        if (rawInput.length > 0) {

            util.log("[" + client.address + "]: " + rawInput);

            match = rawInput.match(/^\.(\w*)\s*(.*)/);

            if (match !== null && match !== undefined) {
                command = match[1];
                arg = match[2].trim();
                if (command.match(/^quit/)) {
                    IttyChat.cmdQuit(client);
                } else if (command.match(/^connect/)) {
                    IttyChat.cmdConnect(client, arg);
                } else if (command.match(/^nick/)) {
                    IttyChat.cmdNick(client, arg);
                } else if (command.match(/^who/)) {
                    IttyChat.cmdWho(client);
                } else if (command.match(/^me/)) {
                    IttyChat.cmdMe(client, arg);
                } else if (command.match(/^say/)) {
                    IttyChat.cmdSay(client, arg);
                } else {
                    client.notify("Huh?");
                }
            } else {
                IttyChat.cmdSay(client, rawInput);
            }
        }
    },

    /*
     * Handle receiving a SIGINT
     */
    sigIntHandler: function () {
        util.log('Cleaning up...');
        Clients.notifyAll("System going down RIGHT NOW!\r\n");
        util.log('Bye!');
        process.exit(0);
    },

    /*
     * Handle a client socket closing.
     */
    endHandler: function(socket) {
        var client = Clients.findClient(socket);
        var address = client.address;
        var name = client.name;
        util.log("Disconnect from " + client.toString());
        if (client.isAuthenticated) {
            Clients.notifyAuthedExcept(client, name + " has left the chat");
        }
        Clients.removeClient(client);
        util.log("Disconnect from " + address +
                 ". (clients: " + Clients.length() + ")");
    },

    /*
     * Listen for a new client, and handle it.
     */
    clientListener: function(socket) {
        var client, rawInput;

        client = new Client(socket);
        Clients.addClient(client);

        client.sendWelcome(client);

        util.log("Connection from " + client.toString() +
                 " (clients: " + Clients.length() + ")");

        // Handle data sent.
        socket.on('data', function(data) {
            IttyChat.inputHandler(client, data)
        });

        // Handle socket disconnect.
        socket.on('end', function() {
            IttyChat.endHandler(socket);
        });
    }
}

/*************************************************************************
 * Main
 ************************************************************************/

var args, port, localOnly, server;

// Handle SIGINT
process.on('SIGINT', IttyChat.sigIntHandler);

// Parse args
args = process.argv.splice(2);

if (args.length < 1 || args.length > 2) {
    console.log("Usage: node ittychat.js [-l] <port>");
    process.exit(1);
}

// If there's an "-l" argument, we listen only on localhost
localOnly = false;

args.forEach(function(arg) {
    if (arg === "-l") {
        localOnly = true;
    }
});

// Last argument is assumed to be the port
port = parseInt(args[args.length - 1]);

if (port > 1024) {
    var server = net.createServer(IttyChat.clientListener);
    if (localOnly) {
        server.listen(port, '127.0.0.1');
    } else {
        server.listen(port);
    }

    util.log("Now listening on port " + port);
} else {
    console.log("Port number must be > 1024");
    process.exit(1);
}
