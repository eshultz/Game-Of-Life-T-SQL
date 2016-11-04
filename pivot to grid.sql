/****************************************************************************************
		Conway's Game of Life Implemented in T-SQL
		Ver. 0.2 (alpha) proof-of-concept
		Copyright 2016 Eric Shultz
		Date: 11/2/2016

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

*****************************************************************************************/

USE [Life]
GO

/****** Object:  StoredProcedure [dbo].[pivot_to_grid]    Script Date: 11/2/2016 5:14:09 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Eric Shultz
-- Create date: 11/02/2016
-- Description:	Pivots the cell table into a grid display
-- =============================================
CREATE PROCEDURE [dbo].[pivot_to_grid]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @colnames NVARCHAR(max) = stuff((
				SELECT max(CONCAT (
							','
							,quotename(c.[column])
							))
				FROM cell c
				GROUP BY (c.[column])
				ORDER BY (c.[column])
				FOR XML path('')
					,type
				).value('.', 'nvarchar(max)'), 1, 1, '');

	DECLARE @sql VARCHAR(max) = CONCAT (
		' select [row], ',@colnames,
		' from (
			 select 
			 [row],
			 [column],
			 case ([cell_status]) when 1 then ''X'' else '''' end as cell_status
			 from cell
		 ) x 
		 pivot (
			max(x.cell_status)
			for [column] in (',@colnames,')
		 ) p 
		 order by [row]');

	EXECUTE (@sql)
END

GO


