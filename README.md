This repo as of now contains three files, one which is a database creation script for SQL Server 2016, one which is the create script for the sp that generates a new grid, and one which is the actual T-SQL code that runs the game.

You don't have to use the database creation script, there is nothing special about the configuration.

After this most recent spurt of key-smashing, the code is a little messy. Rather, the formatting and logical arrangement. There's a lot of clutter and comments.

This will run a "beacon" 100 generations in under 30 seconds, or a "glider" in about 15 seconds. 50 Random coordinate pairs ran in about 30 seconds, but the first generation took a very long time, then everything died, and it zipped through the 99 remaining generations.

There are further performance improvements that can be made. Right now I just limit my neighbor computation (which is the expensive part) to the rectangle of cells defined by the min/max row and column, plus a one cell border (because dead cells can have neighbors and this is important). This results in a huge performance increase for small, singular objects.

The other remaining difficulty is, how do we visualize this? I don't want to cheat and use something external to SSMS. That's not set in stone though. AFAIK, there's no way to CTRL-R programatically in just T-SQL. Which is what I need.

Anyways, it's working and I can't determine that there are any bugs. Enjoy!

![](/res/poc.jpg)

This will continue to be updated as the project progresses.
