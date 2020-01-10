# Script to update the dynamic IP address associated with an OpenDNS account.

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $passwordFile,

    # Username at OpenDNS
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $username,

    # Network name at OpenDNS
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $netname,

    # Log file name
    [Parameter()]
    [string]
    $logfile = "~/.local/log/update-opendns.log"
)

# Main body of script

# Get password from file and build credentials

if (test-path $passwordFile) {
    $password = Get-Content $passwordFile | ConvertTo-SecureString
} else {
    Write-Error "Could not find password file: " + $passwordFile + " Ensure the path is valid."
    exit
}

$cred = [System.Management.Automation.PSCredential]::new($username,$password)

# Get current public IP address

$myip = [System.Net.Dns]::GetHostByName("myip.opendns.com").AddressList[0].IPAddressToString

# Build URI

$updateURI = 'https://updates.dnsomatic.com/nic/update?hostname=' + $netname + '&myip=' + $myip

# Check if IP address has changed since we last ran

if (test-path -path $env:TMPDIR/update-opendns_myip.txt) {
    if ((Get-Content -Path $env:TMPDIR/update-opendns_myip.txt) -eq $myip) {
        $newIP = $false
    } else {
        $newIP = $true
    }
} else {
    $newIP = $true
}

# Send update if necessary

if ($newIP) {
    
    try {
        $response = Invoke-RestMethod -Uri $updateURI -Method Get -Authentication Basic -Credential $cred     
    }
    catch {
        Write-Error "IP address update to OpenDNS failed. See log file."
    }

    # Write log

    [pscustomobject]@{
        "Time (UTC)" = ([system.datetime]::Utcnow.tostring('u').replace(' ','T'))
        "Network Name" = $netname
        "IP Address" = $myip
        "Update Required" = $newIP
        "Response" = $response
    } | Export-Csv -Path $logfile -Append -NoTypeInformation

    # Write new IP address to temp file

    $myip | Out-File -FilePath $env:TMPDIR/update-opendns_myip.txt

} else {
    
    # Write log

    [pscustomobject]@{
        "Time (UTC)" = ([system.datetime]::Utcnow.tostring('u').replace(' ','T'))
        "Network Name" = $netname
        "IP Address" = $myip
        "Update Required" = $newIP
        "Response" = 'n/a'
    } | Export-Csv -Path $logfile -Append -NoTypeInformation

}