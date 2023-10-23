<#
.SYNOPSIS
  This script creates MSSQL server audit objects in order to write audit logs to the Windows Security Log.
.DESCRIPTION
  This script utilizes the SqlServer PowerShell module to pass Transact-SQL statements to the target SQL server 
  instance, which creates the following SQL server objects:
    - Server Audit object on the master
    - Server Audit Specification object on the master
    - Database Audit Specification object on individual database(s)
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Updated by:     Barker, Griffeth (barkergriffeth@gmail.com)
  Change Date:    2023-03-28
  Purpose/Change: Initial development

  This script requires that the server have Microsoft SQL Server and the SqlServer PowerShell module installed.

  This script is intended to be run via Group Policy Object against Microsoft SQL servers. 
.EXAMPLE
  None
#>

# Timestamp function for logging
function Get-TimeStamp {
  return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
}

###############################################################################################################################
# SCRIPT SETUP                                                                                                                #
###############################################################################################################################

Write-Host "[$(Get-Timestamp)] Setting up..." 
Write-Host "[$(Get-Timestamp)] Checking for existence of C:\temp ..."
$WorkingDir = "C:\temp"
if (Test-Path -Path $WorkingDir){
Write-Host "[$(Get-Timestamp)] Validated working directory." 
}
else {
Write-Host "[$(Get-Timestamp)] Could not find C:\temp - creating it now..." 
New-Item -Path "C:\" -Name "temp" -ItemType "directory" -Force
Write-Host "[$(Get-Timestamp)] Created C:\temp - proceeding." 
}

$FileDate = Get-Date -Format 'yyyyMMdd-HHmm'
Start-Transcript -Path "C:\temp\configure_sql_auditing_$FileDate.log" -Force

###############################################################################################################################
# TRANSACT-SQL VIA SQLSERVER POWERSHELL MODULE                                                                                #
###############################################################################################################################

# Get a list of the databases on the server. This is used to create the Database Audit Specification on each database.
Write-Host "[$(Get-Timestamp)] Getting list of databases to configure..."
try {
  $DbsToAudit = @((Get-SqlDatabase -ServerInstance $($env:COMPUTERNAME) -ErrorAction Stop | Where-Object {$_.Name -ne 'tempdb'}).Name)
  Write-Host "[$(Get-Timestamp)] Got list of databases." 
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to get list of databases! This could be due to the Powershell module not loading properly,"
  Write-Host "[$(Get-Timestamp)] invalid permissions, or a variety of other reasons. The script will now exit."
  Stop-Transcript
  Exit 
}

# Create the Server Audit object using Transact-SQL passed via SqlServer PowerShell Module
Write-Host "[$(Get-Timestamp)] Creating the Server Audit Object [your_audit_name]..." 
try {
  $SvrAuditObj = @"
USE master ;
GO

CREATE SERVER AUDIT [your_audit_name]
TO APPLICATION_LOG ;
GO

ALTER SERVER AUDIT [your_audit_name]
WITH (STATE = ON) ;
"@
  Invoke-Sqlcmd -ServerInstance $($env:COMPUTERNAME) -Query $SvrAuditObj
  Write-Host "[$(Get-Timestamp)] Successfully created the Server Audit Object [your_audit_name]." 
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to create the Server Audit Object [your_audit_name]!" 
}

# Create the Server Audit Specification object using Transact-SQL passed via SqlServer PowerShell Module
Write-Host "[$(Get-Timestamp)] Creating the Server Audit Specification Object [your_audit_name_spec]..." 
try {
  $SvrAuditSpecObj = @"
CREATE SERVER AUDIT SPECIFICATION [your_audit_name_spec]
FOR SERVER AUDIT [your_audit_name]
	ADD ( FAILED_LOGIN_GROUP ),
	ADD ( APPLICATION_ROLE_CHANGE_PASSWORD_GROUP ),
	ADD ( AUDIT_CHANGE_GROUP ),
	ADD ( BACKUP_RESTORE_GROUP ),
	ADD ( DATABASE_CHANGE_GROUP ),
	ADD ( DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP ),
	ADD ( DATABASE_OBJECT_PERMISSION_CHANGE_GROUP ),
	ADD ( DATABASE_OPERATION_GROUP ),
	ADD ( DATABASE_OWNERSHIP_CHANGE_GROUP ),
	ADD ( DATABASE_PERMISSION_CHANGE_GROUP ),
	ADD ( DATABASE_PRINCIPAL_CHANGE_GROUP ),
	ADD ( DATABASE_PRINCIPAL_IMPERSONATION_GROUP ),
	ADD ( DATABASE_ROLE_MEMBER_CHANGE_GROUP ),
	ADD ( FAILED_DATABASE_AUTHENTICATION_GROUP ),
	ADD ( FAILED_LOGIN_GROUP ),
	ADD ( SCHEMA_OBJECT_CHANGE_GROUP ),
	ADD ( SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP ),
	ADD ( SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP ),
	ADD ( SERVER_OBJECT_CHANGE_GROUP ),
	ADD ( SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP ),
	ADD ( SERVER_OBJECT_PERMISSION_CHANGE_GROUP ),
	ADD ( SERVER_OPERATION_GROUP ),
	ADD ( SERVER_ROLE_MEMBER_CHANGE_GROUP ),
	ADD ( SERVER_STATE_CHANGE_GROUP ),
	ADD ( STATEMENT_ROLLBACK_GROUP ) ;
GO

ALTER SERVER AUDIT SPECIFICATION [your_audit_name_spec]
WITH (STATE = ON) ;
"@
  Invoke-Sqlcmd -ServerInstance $($env:COMPUTERNAME) -Query $SvrAuditSpecObj -ErrorAction Stop
  Write-Host "[$(Get-Timestamp)] Successfully created the Server Audit Specification Object [your_audit_name_spec]."
}
catch {
  Write-Host "[$(Get-Timestamp)] Failed to create the Server Audit Specification Object [your_audit_name_spec]!"
}

# Create the Database Audit Specification objects on each database using Transact-SQL passed via SqlServer PowerShell Module
foreach ($DbToAudit in $DbsToAudit){
  Write-Host "[$(Get-Timestamp)] $DbToAudit - Creating the Database Audit Specification Object [your_audit_spec_name]..."
  try {
    $DbAuditSpecObj = @"
USE $DbToAudit ;
GO

CREATE DATABASE AUDIT SPECIFICATION [your_audit_spec_name]
FOR SERVER AUDIT [your_audit_name]
WITH (STATE = ON);
GO
"@
    Invoke-Sqlcmd -ServerInstance $($env:COMPUTERNAME) -Query $DbAuditSpecObj -ErrorAction Stop
    Write-Host "[$(Get-Timestamp)] $DbToAudit - Successfully created the Database Audit Specification Object [your_audit_spec_name]."
  }
  catch {
    Write-Host "[$(Get-Timestamp)] $DbToAudit - Failed to create the Database Audit Specification Object [your_audit_spec_name]!"
  }
}

###############################################################################################################################
# SCRIPT CLEANUP                                                                                                              #
###############################################################################################################################
Stop-Transcript
