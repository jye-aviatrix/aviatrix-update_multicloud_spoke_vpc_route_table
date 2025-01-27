function Get-AvxCID {
    
    if (Test-Path Env:\AVIATRIX_CONTROLLER_IP) {
        $Controller_IP=$env:AVIATRIX_CONTROLLER_IP
    } else {
        throw "Unable to obtain Aviatrix Controller IP from environment variable"        
    }

    if (Test-Path Env:\AVIATRIX_USERNAME) {
        $Username=$env:AVIATRIX_USERNAME
    } else {
        throw "Unable to obtain Aviatrix Controller Username from enironment variable"
    }

    if (Test-Path Env:\AVIATRIX_PASSWORD) {
        $Password=$env:AVIATRIX_PASSWORD
    } else {
        throw "Unable to obtain Aviatrix Controller Password from environment variable"
    }

        
    $Endpoint = "https://$Controller_IP/v2/api"

    $Get_API_Token_Body = @{
        "action" = "get_api_token"
    }

    $Get_API_Token_Result = Invoke-RestMethod -Uri $Endpoint -Body $Get_API_Token_Body -Method GET -SkipCertificateCheck
    if ($Get_API_Token_Result.return) {
        $API_Token = $Get_API_Token_Result.results.api_token
    } else {
        throw "Unable to obtain API token"
    }
    

    $Header = @{
        "X-Access-Key" = $API_Token
    }

    $Body = @{
        "action" = "login"
        "username" = $Username
        "password" = $Password
    }

    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Body -Headers $Header -Method POST -SkipCertificateCheck
    if ($Result.return) {
        return $Result.CID
    } else {
        throw "Unable to obtain CID"
    }
}

# Must check to make sure spoke is attach to transit

function Read-Config {
    $Config = Get-Content "config.json" -Raw | ConvertFrom-Json
    return $Config
}

function Confirm-SpokeToTransitAttachment {
    if (Test-Path Env:\AVIATRIX_CONTROLLER_IP) {
        $Controller_IP=$env:AVIATRIX_CONTROLLER_IP
    } else {
        throw "Unable to obtain Aviatrix Controller IP from environment variable"        
    }

    $CID = Get-AvxCID
    $Endpoint = "https://$Controller_IP/v2/api"

    $Config = Read-Config
    $Spoke_GW_Name = $Config.Spoke_GW_Name

    $Body = @{
        "action" = "list_primary_and_ha_spoke_gateways"
        "CID" = $CID
    }

    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Body -Method POST -SkipCertificateCheck
    if ($Result.return) {
        $Match = $Result.results | Where-Object {$_.name -eq $Spoke_GW_Name}
        if ($Match.length -ne 1) {
            throw "Count of Spoke gateway:$Spoke_GW_Name should be 1, but it's not"
        } else {
            if ([string]::IsNullOrEmpty($Match.transit_gw_name)) {
                throw "Spoke gateway:$Spoke_GW_Name is NOT attached to a transit "
            } else {
                return $true
            }
        }
    } else {
        throw "Unable to get spoke gateway details"
    }
    
}


function Update-SpokeCIDR {

    if (!(Confirm-SpokeToTransitAttachment)) {
        return
    }

    if (Test-Path Env:\AVIATRIX_CONTROLLER_IP) {
        $Controller_IP=$env:AVIATRIX_CONTROLLER_IP
    } else {
        throw "Unable to obtain Aviatrix Controller IP from environment variable"        
    }

    $CID = Get-AvxCID
    $Endpoint = "https://$Controller_IP/v2/api"

    $Config = Read-Config
    $Spoke_GW_Name = $Config.Spoke_GW_Name

    $Body = @{
        "action" = "update_encrypted_spoke_vpc_cidrs"
        "gateway_name" = $Spoke_GW_Name
        "CID" = $CID
    }

    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Body -Method POST -SkipCertificateCheck

    if ($Result.return) {
        Write-Host ($Result.results)
    }
    
}


function Update-SpokeRouteTable {

    Update-SpokeCIDR
    
    if (Test-Path Env:\AVIATRIX_CONTROLLER_IP) {
        $Controller_IP=$env:AVIATRIX_CONTROLLER_IP
    } else {
        throw "Unable to obtain Aviatrix Controller IP from environment variable"        
    }

    $CID = Get-AvxCID
    $Endpoint = "https://$Controller_IP/v1/api"

    $Config = Read-Config
    $Spoke_GW_Name = $Config.Spoke_GW_Name

    $Body = @{
        "action" = "update_multicloud_spoke_vpc_route_table"
        "gateway_name" = $Spoke_GW_Name
        "CID" = $CID
    }

    $Result = $null
    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Body -Method POST -SkipCertificateCheck

    if ($Result.results) {
        # If the result indicate route table successfully updated
        Write-Host ($Result.results)
        return
    } elseif ($Result.reason) {
        # Return the reason why route table didn't get updated.
        Write-Host $Result.reason
        return
    } else {
        throw "Unable update subnet route table"
    }
    
}