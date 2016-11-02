/****************************************************************************************
		Conway's Game of Life
		(implemented in T-SQL)
		Ver. 0.1 (alpha) proof-of-concept
		Author: Eric Shultz
		Date: 11/1/2016

		Note:	I am fully aware that this is not the way SQL is intended to be used.
				This is not the type of code I write on daily basis.
				With that said, this is going to be fun and very, very strange. =)
*****************************************************************************************/

use Life
go

-- prepare the table and vars
-- width and height vars can be changed

declare @width int = 100, 
		@height int = 100,
		@i int = 1,
		@sqlString nvarchar(max),
		@insertString nvarchar(max),
		@updateString nvarchar(max),
		@alive char(1) = 'X',
		@dead char(1) = ''

if object_id('dbo.life') is not null drop table life

create table dbo.life([row] int primary key default 1)

while @i <= @width
begin
	set @sqlString = N'alter table dbo.life add ' + concat(N'[',@i,N']') + N' char(1) default '''''
	exec sp_executesql @sqlString
	set @i = @i+1
end

set @i = 1
while @i <= @height
begin
	set @insertString = concat(N'insert life([row]) values(',@i,')')
	exec sp_executesql @insertString
	set @i = @i + 1
end

--select *
--from life
--order by [row]

/******************************************************************************************************************
								Let's start with a simple proof of concept.																			
								The Life "beacon" looks like this:
                                																					
  1  2  3  4  5  6						  1  2  3  4  5  6																					
1[ ][ ][ ][ ][ ][ ]						1[ ][ ][ ][ ][ ][ ]																					
2[ ][X][X][ ][ ][ ]						2[ ][X][X][ ][ ][ ]																					
3[ ][X][X][ ][ ][ ]						3[ ][X][ ][ ][ ][ ]																					
4[ ][ ][ ][X][X][ ]			==>			4[ ][ ][ ][ ][X][ ]			==> and oscillates back and forth eternally.							
5[ ][ ][ ][X][X][ ]						5[ ][ ][ ][X][X][ ]																					
6[ ][ ][ ][ ][ ][ ]						6[ ][ ][ ][ ][ ][ ]																					

																													
How can we model that in sql server???																				
Let's start by declaring our inital state.																			

If we start with a coordinate list of live cells, we would have something like this:								
											 (row, column)																										
											 -------------																										
												(2,2),																											
												(2,3),																											
												(3,2),																											
												(3,3),																											
												(4,4),																											
												(4,5),																											
												(5,4),																											
												(5,5)																											

So what we have to do is come up with an easy way to turn that list into a sql statement, to initialize the board.
******************************************************************************************************************/

if object_id('tempdb..#init') is not null drop table #init
create table #init([row] int, [column] int)

insert #init([row],[column]) values
	(2,2),
	(2,3),
	(3,2),
	(3,3),
	(4,4),
	(4,5),
	(5,4),
	(5,5)

/************************************************************************************************ 
Now we have a temp table containing our inital live cell coords. 
Let's get these into the life table. 
*************************************************************************************************/

declare @row int, @col int

declare coord_cursor cursor -- gah! cursors are evil you can't do that!
	local static read_only forward_only 
	for 
		select [row],[column] from #init
open coord_cursor

while 1=1
-- loop until explicitly broken out
begin
	fetch next from coord_cursor into @row, @col
	set @updateString = concat(N'update life set [', @col, N'] = ''', @alive, ''' where [row] = ', @row)
	print @updateString
	exec sp_executesql @updateString
	-- exit the loop if there's nothing more to fetch
	if @@FETCH_STATUS <> 0 
	begin 
		break 
	end
end

close coord_cursor
deallocate coord_cursor

select *
from life
order by [row]

-- ok, that may seem pretty complicated for many people. dynamic sql? cursors? what is this black magic?
-- unfortunately, we haven't even begun to look at how to implement spatial logic yet. buckle up kiddos!

/*****************************************(From Wikipedia)********************************************************
 *  The universe of the Game of Life is an infinite two-dimensional orthogonal grid of square cells,			 * [we will have to do without "infinite" grids]
 *  each of which is in one of two possible states, alive or dead, or "populated" or "unpopulated"			     *
 *  (the difference may seem minor, except when viewing it as an early model of human/urban behavior simulation  *
 *  or how one views a blank space on a grid). 																	 *
 *  Every cell interacts with its eight neighbours, which are the cells that are horizontally, vertically,		 * 
 *  or diagonally adjacent. At each step in time, the following transitions occur:								 *
 *  																											 *
 *  Any live cell with fewer than two live neighbours dies, as if caused by under-population.					 * 
 *  Any live cell with two or three live neighbours lives on to the next generation.							 *
 *  Any live cell with more than three live neighbours dies, as if by over-population.							 *
 *  Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.				 *
 *  The initial pattern constitutes the seed of the system. 													 *
 *  The first generation is created by applying the above rules simultaneously 									 *
 *  to every cell in the seed -- births and deaths occur simultaneously, 										 *
 *  and the discrete moment at which this happens is sometimes called a tick 									 *
 *  (in other words, each generation is a pure function of the preceding one). 									 *
 *  The rules continue to be applied repeatedly to create further generations.									 *
 *****************************************************************************************************************/

 /***************************************************************************** 
	Alright - how do we even begin? 
    What information do we need to gather for each cell?

	For each cell, we simply need to know 3 things: 
		1. Its coordinates
		2. Its status (alive or dead)
		3. How many live cells it touches (aka neighbors)

	So, we can store all this information in a table in a straightforward way.
	Let's begin.
******************************************************************************/

if object_id('tempdb..#cell') is not null drop table #cell
create table #cell(
	[row] int not null,
	[column] int not null,
	cell_status bit not null default 0, -- 0 for dead and 1 for alive
	neighbors tinyint not null default 0)

with [columns] as (
	select COLUMN_NAME 
	from INFORMATION_SCHEMA.COLUMNS 
	where TABLE_CATALOG = 'Life' 
		and TABLE_SCHEMA = 'dbo' 
		and TABLE_NAME = 'life' 
		and COLUMN_NAME not like 'row'
), 
[rows] as (select [row] from life)
	
insert #cell([row],[column])
select *
from [columns] 
outer apply [rows]
order by 1,2

--select *
--from #cell
--order by 1,2

declare cell_cursor cursor local static read_only forward_only 
	for 
		select [row],[column] from #cell
open cell_cursor
while 1=1
begin
	fetch next from cell_cursor into @row, @col
	set @updateString = concat(
		N'
		update #cell 
		set cell_status = case(select [', @col, N'] from life where [row] = ', @row, ') 
							when ''X'' then 1 
							else 0 
							end
		where [row] = ', @row, ' and [column] = ', @col)
	print @updateString
	exec sp_executesql @updateString
	if @@FETCH_STATUS <> 0 
	begin 
		break 
	end
end
close cell_cursor
deallocate cell_cursor

--select * from #cell
--order by 1,2

-- Determine neighbors:
-- a cell's neighbors are any other live cells with column +- 0,1 and row +- 0,1 from the original cell (excluding the original cell itself)

if object_id('tempdb..#neighbors') is not null drop table #neighbors

	select 
		c.[row],
		c.[column],
		sq.new_neighbors 
	into #neighbors
	from #cell c
	cross apply (
		select sum(cast(cell_status as int)) as new_neighbors 
		from #cell 
		where 
			-- the cells locations differ by no more than both one row and one column in any direction
			abs([row] - c.[row]) <=1 
			and abs([column] - c.[column]) <=1
			-- exclude the self "neighbor"
			and ([column] != c.[column] or [row] != c.[row])
	) sq

update #cell set neighbors = (select n.new_neighbors from #neighbors n where #cell.[row] = n.[row] and #cell.[column]= n.[column])

select * from #cell

/***********************************************************************************************************
	Alright! This is coming along nicely. The queries are ... not very elegant, but they work for now.
	Now, lets iterate to the next generation. 
	Remember:

	Any live cell with fewer than two live neighbours dies, as if caused by under-population.
	Any live cell with two or three live neighbours lives on to the next generation.
	Any live cell with more than three live neighbours dies, as if by over-population.
	Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.

	So, we need to map this out somehow.
	Let's add a column to our #cell table, called "next_gen" 
************************************************************************************************************/

alter table #cell add next_gen bit default 0

update #cell 
set next_gen = 
	case 
	when cell_status = 1 then 
		case 
		when neighbors < 2 then 0
		when neighbors > 3 then 0
		else 1 end
	when cell_status = 0 and neighbors = 3 then 1 else 0 end

--select *
--from #cell
--order by 1,2

declare gen_cursor cursor for select [row], [column], [next_gen] from #cell
open gen_cursor
while 1=1
begin
	fetch next from gen_cursor into @row, @col, @i
	set @updateString = concat('update life set [',@col,'] = case when ', @i, ' = 0 then '''' else ''X'' end where [row] = ', @row)
	exec sp_executesql @updatestring
if @@FETCH_STATUS <> 0
	begin
		break
	end
end
close gen_cursor
deallocate gen_cursor

select * from life

-- Holy shit, it works. This took 44 seconds on my machine to get this far, so I think some performance improvements are in order.
