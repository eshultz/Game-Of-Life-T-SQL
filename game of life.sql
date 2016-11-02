/****************************************************************************************
		Conway's Game of @life
		(implemented in T-SQL)
		Ver. 0.2 (alpha) proof-of-concept
		Author: Eric Shultz
		Date: 11/2/2016

		Note:	I am fully aware that this is not the way SQL is intended to be used.
				This is not the type of code I write on daily basis.
				With that said, this is going to be fun and very, very strange. =)
*****************************************************************************************/

use Life
go

set nocount on;

declare @start_time datetime = getdate();
-- prepare the table and vars
-- width and height vars can be changed

declare @width int = 100, 
		@height int = 100,
		@row int, 
		@col int,
		@i int = 1,
		@sqlString nvarchar(max) = '',
		@alive char(1) = 'X',
		@dead char(1) = '',
		@newline char(1) = char(13);

if object_id('dbo.life') is not null drop table life;
create table life([row] int primary key default 1);

if object_id('dbo.[init]') is not null drop table [init];
create table [init]([row] int, [column] int);

if object_id('dbo.cell') is not null drop table cell;
create table cell(
	[row] int not null,
	[column] int not null,
	cell_status tinyint not null default 0, -- 0 for dead and 1 for alive - using 'bit' here causes problems with aggregation
	neighbors tinyint not null default 0
	constraint pk_cell_row_column primary key ([row],[column]));

--print(concat('#BEGIN: ',datediff(second, @start_time, getdate())));

--print(concat('#BEGIN build string to add columns to ''life'': ' ,datediff(second, @start_time, getdate())))

while @i <= @width
begin
	set @sqlString = @sqlString + 'alter table life add ' + concat('[',@i,']') + ' char(1) default '''';' + @newline
	set @i = @i+1
end

--print(concat('#END: ' ,datediff(second, @start_time, getdate())))
--print(concat('#BEGIN: exec sql for adding columns to ''life'': ' ,datediff(second, @start_time, getdate())))

exec sp_executesql @sqlString;

--print(concat('#END: ' ,datediff(second, @start_time, getdate())))
--print(concat('#BEGIN: build string to insert rows into ''life'': ' ,datediff(second, @start_time, getdate())))

set @sqlString = '';
set @i = 1
while @i <= @height
begin
	set @sqlString = concat(@sqlString,'insert life([row]) values(',@i,');',@newline)
	set @i = @i + 1
end

--print(concat('#END: ',datediff(second, @start_time, getdate())))
--print(concat('#Begin exec sql for insert rows into ''life'': ',datediff(second, @start_time, getdate())))

exec sp_executesql @sqlString

--print(concat('#END: ',datediff(second, @start_time, getdate())))
/******************************************************************************************************************
								Let's start with a simple proof of concept.																			
								The @life "beacon" looks like this:
                                																					
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
Here is a glider:     
  1  2  3  4  5  6	   
1[ ][ ][ ][ ][ ][ ]	
2[ ][ ][X][ ][ ][ ]	
3[ ][ ][ ][X][ ][ ]	
4[ ][X][X][X][ ][ ]	
5[ ][ ][ ][ ][ ][ ]	
6[ ][ ][ ][ ][ ][ ]	



So what we have to do is come up with an easy way to turn that list into a sql statement, to initialize the board.
******************************************************************************************************************/
--print(concat('#BEGIN insert coords into [init] table: ',datediff(second, @start_time, getdate())))
/*--beacon
insert [init] ([row],[column]) values
	(2,2),
	(2,3),
	(3,2),
	(3,3),
	(4,4),
	(4,5),
	(5,4),
	(5,5)
--*/
--/*--glider
insert [init] ([row],[column]) values
	(2,3),
	(3,4),
	(4,2),
	(4,3),
	(4,4)
--*/
/*-- random data, let's see what happens:
insert [init] ([row],[column]) values
(94,98),
(22,65),
(69,98),
(84,54),
(77,92),
(27,24),
(75,19),
(2,19),
(53,43),
(35,42),
(31,15),
(35,91),
(98,94),
(28,37),
(37,87),
(86,51),
(43,67),
(27,18),
(84,60),
(75,77),
(26,11),
(30,12),
(17,89),
(43,8),
(12,96),
(55,72),
(43,69),
(64,17),
(48,26),
(7,68),
(11,93),
(2,81),
(4,6),
(14,40),
(84,91),
(10,1),
(61,60),
(96,59),
(23,7),
(21,97),
(80,39),
(59,89),
(88,26),
(12,40),
(27,47),
(80,29),
(33,55),
(76,12),
(95,65),
(67,62)
--*/

--print(concat('#END: ',datediff(second, @start_time, getdate())))
/************************************************************************************************ 
Now we have a table containing our inital live cell coords. 
Let's get these into the life table. 
*************************************************************************************************/
--print(concat('#BEGIN cursor loop to generate string to mark cells as alive: ' ,datediff(second, @start_time, getdate())))

set @sqlString = ''
declare coord_cursor cursor local static read_only forward_only
	for select [row],[column] from [init];
open coord_cursor
while 1=1 -- loop until explicitly broken out
begin
	fetch next from coord_cursor into @row, @col
	set @sqlString = concat(@sqlString, 'update life set [', @col, '] = ''', @alive, ''' where [row] = ', @row, ';', @newline)
	if @@FETCH_STATUS <> 0 	-- exit the loop if there's nothing more to fetch
	begin break end
end
close coord_cursor
deallocate coord_cursor

--print(concat('#END: ' ,datediff(second, @start_time, getdate())))
--print(concat('#BEGIN execute sql to update ''life'' table with live cells: ' ,datediff(second, @start_time, getdate())))

exec sp_executesql @sqlString

--print(concat('#END: ',datediff(second, @start_time, getdate())))

select *
from life
order by [row]

-- ok, that may seem pretty complicated for many people. dynamic sql? cursors? what is this black magic?
-- unfortunately, we haven't even begun to look at how to implement spatial logic yet. buckle up kiddos!

/*****************************************(From Wikipedia)********************************************************
 *  The universe of the Game of @life is an infinite two-dimensional orthogonal grid of square cells,			 * [we will have to do without "infinite" grids]
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
--print(concat('#BEGIN cte usage and insert into cell just the coords: ',datediff(second, @start_time, getdate())));

;with [columns] as (
	select COLUMN_NAME 
	from INFORMATION_SCHEMA.COLUMNS 
	where TABLE_CATALOG = 'Life' 
		and TABLE_SCHEMA = 'dbo' 
		and TABLE_NAME = 'life' 
		and COLUMN_NAME not like 'row'
), 
[rows] as (select [row] from life)
	
insert cell([row],[column])
select *
from [columns] 
outer apply [rows]
order by 1,2

--print(concat('#END: ',datediff(second, @start_time, getdate())))
--print(concat('#BEGIN set cell.cell_status from init: ',datediff(second, @start_time, getdate())))

update cell 
set cell_status = 1 
from cell c
inner join [init] i
on i.[row] = c.[row] and i.[column] = c.[column]

--print(concat('#END: ',datediff(second, @start_time, getdate())))
/*********************************************************************************************************
                                        Main loop begins here.
*********************************************************************************************************/

set @i = 0
while @i < 100
begin
	--print(concat('#BEGIN compute and update neighbors values for each coord using cross apply): ' ,datediff(second, @start_time, getdate())))

	declare @min_col int = (select min([column]) from cell c where c.cell_status != @dead);
	declare @max_col int = (select max([column]) from cell c where c.cell_status != @dead);
	declare @min_row int = (select min([row]) from cell c where c.cell_status != @dead);
	declare @max_row int = (select max([row]) from cell c where c.cell_status != @dead);

	update cell set neighbors = new_neighbors
	from cell c
	cross apply (
		select sum(cell_status) as new_neighbors 
		from cell 
		where 
			-- the cells locations differ by no more than both one row and one column in any direction
			([row] - c.[row] between -1 and 1) 
			and ([column] - c.[column] between -1 and 1)
			and ([column] != c.[column] or [row] != c.[row])
	) sq
	where 
		c.[row] between (@min_row-1) and (@max_row+1) and
		c.[column] between (@min_col-1) and (@max_col+1)

	--print(concat('#END: ',datediff(second, @start_time, getdate())))
	/***********************************************************************************************************
		Iterate to the next generation.
		Remember:
		Any live cell with fewer than two live neighbours dies, as if caused by under-population.
		Any live cell with two or three live neighbours lives on to the next generation.
		Any live cell with more than three live neighbours dies, as if by over-population.
		Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
	************************************************************************************************************/
	--print(concat('#BEGIN update cell by computing the next generation: ' ,datediff(second, @start_time, getdate())))

	update cell 
	set cell_status = 
		case 
		when cell_status = 1 then 
			case 
			when neighbors < 2 then 0
			when neighbors > 3 then 0
			else 1 end
		when cell_status = 0 and neighbors = 3 then 1 else 0 end

	--print(concat('#END: ' ,datediff(second, @start_time, getdate())))
	--print(concat('#BEGIN update ''life'' table using the sp ''pivot_to_grid'': ',datediff(second, @start_time, getdate())))

	truncate table life;
	insert life exec pivot_to_grid

	--print(concat('#END: ' ,datediff(second, @start_time, getdate())))

	select * from life
	
	set @i = @i+1;
end
-- 0.1: Holy shit, it works. This took 44 seconds on my machine to get this far, so I think some performance improvements are in order.
-- 0.2: Performance improvements! 7 seconds! Strike that, 0 seconds! Time to loop.
-- I am getting 100 generations in 24 seconds with a simple "Beacon". That's pretty dang good, I think. But, some of these optimizations will fall apart with more complex boards.
-- The performance isn't much worse with random data, about 30 seconds, but not very interesting.
-- I need to find a way to visualize this more easily.
