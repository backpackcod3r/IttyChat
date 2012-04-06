IttyChat
========

This is a very simple proof-of-concept chat server that accepts Telnet
connections and drops all connected users into a single "chat room". Think IRC,
but much, much less useful.

Running the Server
------------------

Just run with node.js and CoffeeScript as follows:

    % coffee ittychat.coffee 3000

This will start the server listening on port 3000.

If you want to limit the server to listening only on localhost, use
the "-l" argument:

    % coffee ittychat.coffee -l 3000

This is useful for debugging, kicking the tires, etc.

Logging is written to STDOUT, so you'll want to redirect to a log file if
you're interested in saving it

Using the Chat
--------------

Since this is a line-oriented server, a client program such as TinyFugue[1] (or
equivalent) is highly recommended. It makes the experience much more pleasant!
Raw telnet works fine in a pinch, however.

All user commands begin with a period, and are summarized below:

### .who

  Print a list of all the userse in the chat.

### .connect [username]

  Join the chat with the given username.

### .quit

  Leave the chat and disconnect.

### .me [msg]

  Pose command. Displays your username followed by the message.  For
  example, if your name is "JimBob":

    '.me slaps himself with a fish'

  Will display

    '* JimBob slaps himself with a fish'

  to all the users in the chat.

### .say [msg]

  Speak the given message to the room. For example, if your name is
  "JimBob":

    '.say Hello!'

  Will display

    '[JimBob]: Hello!'

  to all the users in the chat.

  Additionally, any input that is NOT prefixed with a slash will be assumed
  to be the '.say' command.

### .nick [newname]

  Will change your nickname from your current name to the new name.

Customizing the Server
---------------------

The following files can be customized:

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

TODO
----

* Unit Testing. This really should have come first!

* Deal with idle sockets.

* Deal with chunked input.

* Allow a 'max_clients' variable to be set.

* SSL connections.

* Authentication
  - Shared password for connections?
    - Would require a single variable to set the secret.
  - Per-user password hash for connections?
    - Would require a simple file store for user / crypted pass

* Multiple chat rooms


Design Philosophy
-----------------

My goal with this project, first and foremost, was to learn Node.js.
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

Copyright (c) 2012 Seth J. Morabito &lt;web@loomcom.com&gt;

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


Footnotes
---------

[1] http://tinyfugue.sourceforge.net/
