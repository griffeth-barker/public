/***************************************************************************************************
Procedure:          None
Create Date:        2023-03-22
Author:             Griffeth Barker (barkergriffeth@gmail.com)
Description:        A simple query that helps retrieve a filtered list of Configuration Items from
                    ManageEngine Service Desk Plus' CMDB module. This was initially written out of
                    necessity, needing a list of CIs but only firewalls, switches, routers, Linux
                    servers, Windows servers, and ESXi servers. It was written with the intention of
                    passing the query to the CMDB API endpoint of a ManageEngine instance. I
                    understand this is probably not all that useful to most people, but I leave it
                    here as a personal reminder, and on the off-chance that some newer IT admin
                    down the road has the same need I had and might make use of it.
                    
                    No data is changed in the database, this is a read-only query.
                    
Affected table(s):  [servicedesk.dbo.CI]
                    [servicedesk.dbo.Resources]
Used By:            IT personnel
Parameter(s):       None
Usage:              The CITYPEIDs below are environment-specific and would need to be changed to fit
                    your environemnt.
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
2023-03-22          Griffeth Barker     Initial commit
***************************************************************************************************/

SELECT CIID, CINAME
FROM CI as CMDB
WHERE (CMDB.CITYPEID=31 OR CMDB.CITYPEID=13 OR CMDB.CITYPEID=2701 OR CMDB.CITYPEID=19 OR CMDB.CITYPEID=11 OR CMDB.CITYPEID=9)
AND EXISTS 
(SELECT * 
	FROM Resources AS Assets
	WHERE (Assets.RESOURCESTATEID=1 OR Assets.RESOURCESTATEID=2)
	AND CMDB.CIID = Assets.CIID) 
ORDER BY CINAME ;
