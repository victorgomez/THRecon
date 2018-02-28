function Get-THR_SCCM_BHO {
    <#
    .SYNOPSIS 
        Queries SCCM for a given hostname, FQDN, or IP address.

    .DESCRIPTION 
        Queries SCCM for a given hostname, FQDN, or IP address.

    .PARAMETER Computer  
        Computer can be a single hostname, FQDN, or IP address.

    .PARAMETER CIM
        Use Get-CIMInstance rather than Get-WMIObject. CIM cmdlets use WSMAN (WinRM)
        to connect to remote machines, and has better standardized output (e.g. 
        datetime format). CIM cmdlets require the querying user to be a member of 
        Administrators or WinRMRemoteWMIUsers_ on the target system. Get-WMIObject 
        is the default due to lower permission requirements, but can be blocked by 
        firewalls in some environments.

    .EXAMPLE 
        Get-THR_SCCM_BHO 
        Get-THR_SCCM_BHO SomeHostName.domain.com
        Get-Content C:\hosts.csv | Get-THR_SCCM_BHO
        Get-THR_SCCM_BHO $env:computername
        Get-ADComputer -filter * | Select -ExpandProperty Name | Get-THR_SCCM_BHO

    .NOTES 
        Updated: 2018-02-07

        Contributing Authors:
            Anthony Phipps
            
        LEGAL: Copyright (C) 2018
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

    .LINK
       https://github.com/TonyPhipps/THRecon
    #>

    param(
    	[Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        $Computer,

        [Parameter()]
        $SiteName="A1",

        [Parameter()]
        $SCCMServer="server.domain.com",
        
        [Parameter()]
        [switch]$CIM
    )

	begin{
        $SCCMNameSpace="root\sms\site_$SiteName"

        $datetime = Get-Date -Format "yyyy-MM-dd_hh.mm.ss.ff"
        Write-Information -InformationAction Continue -MessageData ("Started {0} at {1}" -f $MyInvocation.MyCommand.Name, $datetime)

        $stopwatch = New-Object System.Diagnostics.Stopwatch
        $stopwatch.Start()

        $total = 0
	}

    process{        
                
        if ($Computer -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"){ # is this an IP address?
            
            $fqdn = [System.Net.Dns]::GetHostByAddress($Computer).Hostname
            $ThisComputer = $fqdn.Split(".")[0]
        }
        
        else{ # Convert any FQDN into just hostname
            
            $ThisComputer = $Computer.Split(".")[0].Replace('"', '')
        }

        $output = [PSCustomObject]@{
            Name = $ThisComputer
            ResourceNames = ""
            Description = ""
            FileName = ""
            FilePropertiesHash = ""
            FilePropertiesHashEx = ""
            FileVersion = ""
            Product = ""
            ProductVersion = ""
            Publisher = ""
            RevisionID = ""
            Timestamp = ""
        }

        if ($CIM){

            $SMS_R_System = Get-CIMInstance -namespace $SCCMNameSpace -computer $SCCMServer -query "select ResourceNames, ResourceID from SMS_R_System where name='$ThisComputer'"
            $ResourceID = $SMS_R_System.ResourceID # Needed since -query seems to lack support for calling $SMS_R_System.ResourceID directly.
            $SMS_G_System_BROWSER_HELPER_OBJECT = Get-CIMInstance -namespace $SCCMNameSpace -computer $SCCMServer -query "select Description, FileName, FilePropertiesHash, FilePropertiesHashEx, FileVersion, Product, ProductVersion, Publisher, RevisionID, Timestamp from SMS_G_System_BROWSER_HELPER_OBJECT where ResourceID='$ResourceID'"
        }
        else{
            $SMS_R_System = Get-WmiObject -namespace $SCCMNameSpace -computer $SCCMServer -query "select ResourceNames, ResourceID from SMS_R_System where name='$ThisComputer'"
            $ResourceID = $SMS_R_System.ResourceID # Needed since -query seems to lack support for calling $SMS_R_System.ResourceID directly.
            $SMS_G_System_BROWSER_HELPER_OBJECT = Get-WmiObject -namespace $SCCMNameSpace -computer $SCCMServer -query "select Description, FileName, FilePropertiesHash, FilePropertiesHashEx, FileVersion, Product, ProductVersion, Publisher, RevisionID, Timestamp from SMS_G_System_BROWSER_HELPER_OBJECT where ResourceID='$ResourceID'"
        }

        if ($SMS_G_System_BROWSER_HELPER_OBJECT){
                
            $SMS_G_System_BROWSER_HELPER_OBJECT | ForEach-Object {
                
                $output.ResourceNames = $SMS_R_System.ResourceNames[0]

                $output.DESCRIPTION = $_.DESCRIPTION
                $output.FileName = $_.FileName
                $output.FilePropertiesHash = $_.FilePropertiesHash
                $output.FilePropertiesHashEx = $_.FilePropertiesHashEx
                $output.FileVersion = $_.FileVersion
                $output.Product = $_.Product
                $output.ProductVersion = $_.ProductVersion
                $output.Publisher = $_.Publisher
                $output.RevisionID = $_.RevisionID
                $output.Timestamp = $_.Timestamp

                return $output
                $output.PsObject.Members | ForEach-Object {$output.PsObject.Members.Remove($_.Name)} 
            }
        }
        else {

            return $output
            $output.PsObject.Members | ForEach-Object {$output.PsObject.Members.Remove($_.Name)} 
        }

        $elapsed = $stopwatch.Elapsed
        $total = $total+1
            
        Write-Verbose -Message "System $total `t $ThisComputer `t Time Elapsed: $elapsed"

    }

    end{
        $elapsed = $stopwatch.Elapsed
        Write-Verbose "Total Systems: $total `t Total time elapsed: $elapsed"
	}
}


