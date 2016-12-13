IttyChat
========

This is a simple chat server that accepts Telnet connections and drops
all connected users into a single "chat room". Think IRC, but much,
much less useful.

Users are persistent and stored in a SQLite database between sessions.


Running the Server
------------------

It's easiest to use `npm` to run the server. First install dependencies with:

    % npm install -g coffee-script
    % npm install

Then run the server. By default, this will listen on all interfaces,
on the default port, 8888:

    % npm start

If you'd prefer to launch the server manually, use the command:

    % coffee ittychat.coffee 3000

This will start the server listening on port 3000.

If you want to limit the server to listening only on localhost, use
the `-l` argument:

    % coffee ittychat.coffee -l 3000

This is useful for debugging, kicking the tires, etc.

Logs are stored in the directory `logs`.

Using the Chat
--------------

Since this is a line-oriented server, a client program such as
[TinyFugue] (http://tinyfugue.sourceforge.net/) or an equivalent is
highly recommended. It makes the experience much more pleasant!  Raw
telnet works fine in a pinch, however.

Each line must begin with a recognized command:

### help

Display a help file.

### quit

Leave the chat and disconnect.

### who

Print a list of all the userse in the chat.

### register [username] [password] [email]

Register a new user. Username, password, and email address are all
required.

### connect [username] [password]

Join the chat as a previously registered user.

### nick [newname]

Will change your nickname from your current name to the new name.

### say [msg] (or "[msg])

Speak the given message to the room. For example, if your name is
"JimBob":

    say Hello!

or, equivalently

    "Hello!

Will display

    JimBob says "Hello!"

to all the users in the chat.

### me [msg]

Pose command. Displays your username followed by the message.  For
example, if your name is "JimBob":

    me slaps himself with a fish

or, equivalently

    :slaps himself with a fish

Will display

    JimBob slaps himself with a fish

to all the users in the chat.


Customizing the Server
---------------------

The following files in the `etc` directory can be customized:

### welcome.txt

The text in this file is sent to clients when they connect. Normally
it should include a short bit of help, sysadmin contact information,
etc.

### motd.txt

This is the "Message of the Day", and is displayed to users after they
join the chat by using the .connect command. If this file is missing,
no motd will be shown.

### help.txt

This is the text displayed by the .help command. You probably don't
need to edit this file unless you hack on the server and add, delete,
or modify commands.

Testing
-------

IttyChat makes use of [Mocha] (http://mochajs.org/)
for test coverage. All specs are in the `IttyChat/test` directory. You
can optionally install the `mocha` package and test with npm:

    % npm install
    % npm test

If you prefer to run the mocha command by hand,

    % ITTYCHAT_ENV=test mocha -s 250 --compilers coffee:coffee-script

TODO
----

* Deal with idle sockets?

* Deal with chunked input?

* Allow a 'max_clients' variable to be set.

* SSL connections.

* Multiple chat rooms.


Design Philosophy
-----------------

My goal with this project was, first and foremost, to learn Node.js.
This is my first attempt at a project in Node.js, so I wanted to do
something that I found genuinely interesting but simple enough to bite
off in an evening or weekend. Chat servers are well known problems,
there's nothing new here, but they are still complex enough to have fun
with.

The first implementation was JavaScript, but since I was cutting my
teeth on new (to me) technologies, I re-wrote it in CoffeeScript and
killed two birds with one stone.

The JavaScript branch still lives in GitHub, but any new changes
will bee in CoffeeScript on the master branch.


License
-------

Copyright (c) 2013 Seth J. Morabito &lt;web@loomcom.com&gt;

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
