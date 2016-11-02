# Conway's Game of Life (in pure T-SQL)
##### Have you ever wondered if you could create a simple game in SQL Server? 
##### I did, for a long time, so one night I sat down and did it.

---
This is the result.
---

- [game of life](game of life.sql): this runs the game
- [pivot to grid](pivot to grid.sql): an sp which creates the board for the current generation
- [Life db script](Life db script.sql): run this to create the database itself - not necessary, there's nothing special about it

After this most recent spurt of key-smashing, the code is a little messy. Rather, the formatting and logical arrangement. There's a lot of clutter and comments. That will be addressed soon.

### Performance

*all tests are 100x100 board, 100 generations, SQL Server 2016 Express, Core i5-6500 3.2GHz, 8GB DDR4, SSD*

||||
|---|---|---|
|"glider"|15s|![](/res/Game_of_life_animated_glider.gif)|
|"beacon"|27s|![](/res/Game_of_life_beacon.gif)|
|50 random coordinate pairs|about 30 seconds[^1]| :question: |

There are further performance improvements that can be made. Right now I just limit my neighbor computation (which is the expensive part) to the rectangle of cells defined by the min/max row and column, plus a one cell border (because dead cells can have neighbors and this is important). 
This results in a huge performance increase for small, singular objects, but very little benefit for spread-out or large objects.

The other remaining difficulty is, how do we visualize this? I don't want to cheat and use something external to SSMS. AFAIK, there's no way to CTRL-R programatically in just T-SQL. Which is what I need.
(That's not set in stone though.)

Anyways, it's working and I can't determine that there are any bugs. Enjoy!

[^1]: The first generation took a _very_ long time, then everything died, and it zipped through the 99 remaining generations.

![](/res/poc.jpg)

This will continue to be updated as the project progresses.
