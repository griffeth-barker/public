/***************************************************************************************************
Create Date:        2018-01-01

Author:             Barker, Griffeth (barkergriffeth@gmail.com)

Description:        This query returns the ID, ProfileNo, and Name of KeyWatcher TrueTouch profiles.

Affected table(s):  [EKO_KWT_KWMain2.dbo.tblProfile]

Used By:            IT systems administrators use this script at the request of Accounting personnel.

Parameter(s):       None

Usage:              The output of this is helpful to the accounting and compliance team at GDW Elko
                    because TrueTouch reporting will show the database ID in the reports for
                    transactions, which is not shown anywhere in the software's graphical user
                    interface (GUI). They may periodically request an updated copy of the output of
                    this query.
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------- ------------------------------------------------------------
2018-01-01          Barker, Griffeth    Initial development

***************************************************************************************************/

SELECT 
    ID AS 'Database ID',
    ProfileNo AS 'Profile Number',
    Name AS 'Profile Name'
FROM tblProfile
ORDER BY ID
