# The name of the light
$LightName = "Hue go 1"

# The Bridge IP address
$Endpoint = "192.168.1.12"

# The username created on the bridge
$UserID = "38cbd1cbcac542f9c26ad393739b7"


#############
# FUNCTIONS #
#############

Function Get-HueLight {
    <#
    Returns the light number in the bridge from its friendly name - basically a search.
    #>
    param([parameter(Mandatory=$true)][string] $BridgeIP,
          [parameter(Mandatory=$true)][string] $UserID,
          [parameter(Mandatory=$true)][string] $LightFriendlyName
    )
    $HueData = Invoke-RestMethod -Method Get -Uri "http://$BridgeIP/api/$UserID/lights"

    # Parse all light data to find the name of the light to tinker with
    $Lights = $HueData.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
    [string]$Light = $Lights | Where-Object {$_.Value.Name -match $LightFriendlyName}  | Select Name -ExpandProperty Name
    Return $Light
}

Function Switch-HueLight  {
    <#
    Switches the state of the light.
    If you don't specify the state (on or off) then
    if on, turns off. If off, turns on.
    #>

    param([parameter(Mandatory=$true)][string] $BridgeIP,
          [parameter(Mandatory=$true)][string] $UserID,
          [parameter(Mandatory=$true)][string] $LightNumber,
          [ValidateSet( "On", "Off" )]
          [string[]]
          $State
    )

    $Light = Invoke-RestMethod -Method Get -Uri "http://$BridgeIP/api/$UserID/lights/$LightNumber"
    
    # Haven't specified the state, so toggle it.
    # Very verbose, uses the current light's state information but could just
    # set the JSON ourselves as per Set-HueLight
    If (!($State)) {
        If ($Light.state.on -eq $true) {
            $Light.state.on = $false
            $Light.state.Psobject.Properties.Remove('colormode')
            $Light.state.Psobject.Properties.Remove('reachable')
            $Result = Invoke-RestMethod -Method Put -Uri "http://$BridgeIP/api/$UserID/lights/$LightNumber/state" -Body (ConvertTo-Json $Light.State)
            Write-Output "Light should now be off."
        }
        Else {
            $Light.state.on = $true
            $Light.state.Psobject.Properties.Remove('colormode')
            $Light.state.Psobject.Properties.Remove('reachable')
            $Result = Invoke-RestMethod -Method Put -Uri "http://$BridgeIP/api/$UserID/lights/$LightNumber/state" -Body (ConvertTo-Json $Light.State)
            Write-Output "Light should now be on."
        }
    }
    Else {

        Switch ($State) {
            On  {$NewState = '{"on": true}'}
            Off {$NewState = '{"on": false}'}
        }
        $Result = Invoke-RestMethod -Method Put -Uri "http://$BridgeIP/api/$UserID/lights/$LightNumber/state" -Body $NewState
    }
}

Function Set-HueLight {
    <#
    Sets the light's ((Hue and Saturation levels) or (Colour Temperature)) and (Brightness), 
    If you set the colour temperature value, Hue and Sat values are ignored (ie. Use one or the other, not both)
    For Hue: Both 0 and 65535 are red, 25500 is green and 46920 is blue.
    For Colour Temp: 153 is 6500K (White), 500 is 2000K (Warm)
    #>
    param([parameter(Mandatory=$true)][string] $BridgeIP,
          [parameter(Mandatory=$true)][string] $UserID,
          [parameter(Mandatory=$true)][string] $LightNumber,
          [ValidateRange(1,254)][int] $Brightness,
          [ValidateRange(0,65535)][int] $Hue,
          [ValidateRange(1,254)][int] $Saturation,
          [ValidateRange(153,500)][int] $ColourTemperature
    )

    $Settings = @{}

    If ($Brightness) {
        $Settings.Add("bri", $Brightness)
    }
    If ($Hue) {
        $Settings.Add("hue", $Hue)
    }
    If ($Saturation) {
        $Settings.Add("sat", $Saturation)
    }
    If ($ColourTemperature) {
        $Settings.Add("ct", $ColourTemperature)
    }

    $Result = Invoke-RestMethod -Method Put -Uri "http://$BridgeIP/api/$UserID/lights/$LightNumber/state" -Body (ConvertTo-Json $Settings)

}

##############
# PROCESSING #
##############

$Light = Get-HueLight -BridgeIP $Endpoint -UserID $UserID -LightFriendlyName $LightName

Switch-HueLight -BridgeIP $Endpoint -UserID $UserID -LightNumber $Light -State On

# Hue Go Default Colour Temperature & Brightness
Set-HueLight -BridgeIP $Endpoint -UserID $UserID -LightNumber $Light -ColourTemperature 370 -Brightness 50

Set-HueLight -BridgeIP $Endpoint -UserID $UserID -LightNumber $Light -Brightness 50 -Hue 25500 -Saturation 254