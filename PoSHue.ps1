Enum LightState {
    # Defines a state of the light for methods that can specify the state of the light to On or Off.
    On = $True
    Off = $False
}

Class HueBridge {
    ##############
    # PROPERTIES #
    ##############

    [ipaddress] $BridgeIP
    [string] $APIKey

    ###############
    # CONSTRUCTOR #
    ###############

    # Constructor to return an API Key
    HueBridge([ipaddress] $Bridge) {
        $this.BridgeIP = $Bridge
    }

    # Constructor to return lights and names of lights.
    HueBridge([ipaddress] $Bridge, [string] $APIKey) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $APIKey
    }

    ###########
    # METHODS #
    ###########

    Static [PSObject] FindHueBridge() {
        $UPnPFinder = New-Object -ComObject UPnP.UPnPDeviceFinder
        $UPnPDevices = $UPnPFinder.FindByType("upnp:rootdevice", 0) | Where-Object {$_.Description -match "Hue"} | Select-Object FriendlyName, PresentationURL, SerialNumber | Format-List
        Return $UPnPDevices
    }
    
    [string] GetNewAPIKey() {
        $Result = Invoke-RestMethod -Method Post -Uri "http://$($this.BridgeIP)/api" -Body '{"devicetype":"PoSHue#PowerShell Hue"}'
        
        If ($Result[0].error) {
            Return $Result[0].error.description
        }
        ElseIf ($Result[0].success) {
            # Assign the API Key and return it.
            $this.APIKey = $Result[0].success.username
            Return $Result[0].success.username
        }
        Else {
            Return "There was an error.`r`n$Result"
        }
    }

    [array] GetLightNames() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }

        $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        $Lights = $Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        Return $Lights.Value.Name

        # The below is not necessary.
        # PoSH extracts the values from the array when an index isn't specified, it seems.
        # Something new every day.
        # Return $Lights | Select-Object @{Name="Hue Light Names"; Expression = {$_.Value.Name}}
    }

    [PSCustomObject] GetAllLights() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        Return $Result
    }

    [void] ToggleAllLights([LightState] $State) {
        # A simple toggle affecting all lights in the system.
        $Settings = @{}
        Switch ($State) {
            On  {$Settings.Add("on", $true)}
            Off {$Settings.Add("on", $false)}
        }
        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups/0/action" -Body (ConvertTo-Json $Settings)
    }
}

Class HueLight {

    ##############
    # PROPERTIES #
    ##############

    [string] $Light
    [string] $LightFriendlyName
    [ipaddress] $BridgeIP
    [string] $APIKey
    [string] $JSON
    [bool] $On
    [ValidateRange(1,254)][int] $Brightness
    [ValidateRange(0,65535)][int] $Hue
    [ValidateRange(1,254)][int] $Saturation
    [ValidateRange(153,500)][int] $ColourTemperature
    [ValidateSet("ct", "xy", "hs")] $ColourMode
    
    ###############
    # CONSTRUCTOR #
    ###############

    HueLight([string] $Name, [ipaddress] $Bridge, [string] $API) {
        $this.LightFriendlyName =  $Name
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
        $this.Light = $this.GetHueLight($Name)
        $this.GetStatus()
    }


    ###########
    # METHODS #
    ###########

    hidden [int] GetHueLight([string] $Name) {
        # Change the named light in to the integer used by the bridge. We use this throughout.
        $HueData = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        $Lights = $HueData.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        $this.Light = $Lights | Where-Object {$_.Value.Name -match $Name}  | Select Name -ExpandProperty Name
        If ($this.Light) {
            Return $this.Light
        }
        Else {
            Throw "No light name matching `"$Name`" was found in the Hue Bridge `"$($this.BridgeIP)`".`r`nTry using [HueBridge]::GetLightNames() to get a full list of light names in this Hue Bridge."
        }
    }

    hidden [void] GetStatus() {
        # Get the current values of the State, Hue, Saturation, Brightness and Colour Temperatures
        $Status = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)"
        $this.On = $Status.state.on
        $this.Brightness = $Status.state.bri
        $this.Hue = $Status.state.hue
        $this.Saturation = $Status.state.sat
        $this.ColourMode = $Status.state.colormode
        If ($Status.state.ct) {
            $this.ColourTemperature = $Status.state.ct
        }
    }

    [void] SwitchHueLight() {
        # A simple toggle. If on, turn off. If off, turn on.
        
        Switch ($this.On) {
            $false  {$this.On = $true}
            $true {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
    }

    [void] SwitchHueLight([LightState] $State) { # An overload for SwitchHueLight
    # Set the state of the light. Always does what you give it, irrespective of the current setting.
        Switch ($State) {
            On  {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
    }

    # Importance of colour settings: XY > CT > HS
    # I don't have an XY method as it seems illogical.
    [string] SetHueLight([int] $Brightness, [int] $ColourTemperature) {
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Brightness and/or Colour Temperature."
        }

        If (!($this.ColourTemperature)) {
            Throw "Light named `"$($this.LightFriendlyName)`" does not hold the `"ct`" setting or it could not be read properly during`r`nobject instantiation. Does it support Colour Temperature? If so, please report a bug."
        }
        $this.Brightness = $Brightness
        $this.ColourTemperature = $ColourTemperature

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("ct", $this.ColourTemperature)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output +=  "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the brightness or colour temperature."}
    }

    [string] SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation) {
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Hue, Saturation and/or Brightness."
        }

        # Allows imposing the ValidateRange limits so it seems advisable to do this
        $this.Brightness = $Brightness
        $this.Hue = $Hue
        $this.Saturation = $Saturation

        # Feels a bit verbose to be updating our object data then re-constructing it for use... what to do...what to do...

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("hue", $this.Hue)
        $Settings.Add("sat", $this.Saturation)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)

        # Handle errors - incomplete in reality but should suffice for now.
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output +=  "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Hue, Saturation or Brightness."}

    }

}
