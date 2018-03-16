Enum LightState {
    # Defines a state of the light for methods that can
    # specify the state of the light to On or Off.
    On = $True
    Off = $False
}

Enum ColourMode {
    # Defines the colour modes that can be set on the light.
    xy
    ct
    hs
}

Enum AlertType {
    # Defines the accepted values when invoking the Breathe method.
    none
    select
    lselect
}

Enum Gamut {
    # Defines the accepted values when invoking the Breathe method.
    GamutA
    GamutB
    GamutC
    GamutDefault
}

Enum RoomClass {
    Kitchen
    Dining
    Bedroom
    Bathroom
    Nursery
    Recreation
    Office
    Gym
    Hallway
    Toilet
    Garage
    Terrace
    Garden
    Driveway
    Carport
    Other
}

Class HueFactory {
    # Base class defining methods shared amongst other classes
    hidden [hashtable] BuildRequestParams([string] $Method, [string] $Uri) {
        $ReqArgs = @{
            Method = $Method
            Uri = $this.ApiUri + $Uri
            ContentType = 'application/json'
        }
        if ($this.RemoteApiAccessToken) {
            $ReqArgs.Add('Headers', @{Authorization = "Bearer $($this.RemoteApiAccessToken)"})
        }
        Return $ReqArgs
    }

    # Return errors and terminates execution
    hidden [void] ReturnError([string] $e) {
        Write-Error $e -ErrorAction Stop
    }

    static [string] GetRemoteApiAccess() {
        Return "To get an access token that permits this module to access your bridge via the Philips`r`nHue Remote API, please open a browser and visit https://www.lewisroberts.com/poshue"
    }

    hidden [datetime] ConvertUnixTime([long] $Milliseconds) {
        Return [System.DateTimeOffset]::FromUnixTimeMilliseconds($Milliseconds).LocalDateTime
    }

    hidden [string] $HueRemoteApiUri = 'https://api.meethue.com/bridge/'

    
    [pscustomobject] GetRemoteApiUsage() {
        if (!($this.RemoteApiAccessToken)) {
            Throw 'This method can only be used where the parent object is using the remote API.'
        }

        # Using a Web Request since Headers aren't available in Invoke-RestMethod in PS5.1
        # 6.0+ would be Invoke-RestMethod @ReqParams -ResponseHeadersVariable HeaderVariable
        $Result = Invoke-WebRequest -Method Get `
                                    -Uri ("{0}{1}/{2}" -f $this.HueRemoteApiUri, $this.APIKey, 'lights') `
                                    -Headers @{Authorization = "Bearer $($this.RemoteApiAccessToken)"} `
                                    -ContentType 'application/json'

        $QuotaObjects = $Result.Headers.Keys | Where-Object {$_ -match 'X-Quota'}

        $Object = @{}
        Foreach ($Item in $QuotaObjects) {
            If ($Item -like '*Time*') {
                $Object.Add($Item.ToString(), $this.ConvertUnixTime([long]$Result.Headers.Item($Item)[0]))
                Continue
            }

            $Object.Add($Item.ToString(),$Result.Headers.Item($Item)[0])
        }
        Return $Object
    }
    

}

Class HueBridge : HueFactory {
    ##############
    # PROPERTIES #
    ##############

    [ipaddress] $BridgeIP
    [ValidateLength(20, 50)][string] $APIKey
    [ValidateLength(20, 50)][string] $RemoteApiAccessToken
    [string] $ApiUri

    ################
    # CONSTRUCTORS #
    ################

    # Constructor to return an API Key
    HueBridge([string] $Bridge) {
        $this.BridgeIP = $Bridge
        $this.ApiUri = "http://$($this.BridgeIP)/api/"
    }

    # Constructor to return lights and names of lights.
    HueBridge([string] $Bridge, [string] $APIKey) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $APIKey
        $this.ApiUri = "http://$($this.BridgeIP)/api/$($this.APIKey)"
    }

    # Use a Remote API session but without a username/whitelist entry.
    HueBridge([string] $RemoteApiAcccessToken, [bool]$RemoteSession) {
        $this.RemoteApiAccessToken = $RemoteApiAcccessToken
        $this.ApiUri = $this.HueRemoteApiUri
    }

    # Use a Remote API session with a username/whitelist entry.
    HueBridge([string] $RemoteApiAcccessToken, [string] $APIKey, [bool] $RemoteSession) {
        $this.RemoteApiAccessToken = $RemoteApiAcccessToken
        $this.APIKey = $APIKey
        $this.ApiUri = "{0}{1}" -f $this.HueRemoteApiUri, $this.APIKey
    }

    ###########
    # METHODS #
    ###########

    static [PSObject] FindHueBridge() {
        if ([System.Environment]::OSVersion.Platform -ne 'Win32NT') {
            Throw 'Searching for your Philips Hue bridge via UPnP is not currently possible on Unix and Mac platforms. Please consult your network equipment to discover the bridge IP address.'
        }
        $UPnPFinder = New-Object -ComObject UPnP.UPnPDeviceFinder
        $UPnPDevices = $UPnPFinder.FindByType("upnp:rootdevice", 0) | Where-Object {$_.Description -match "Hue"} | Select-Object FriendlyName, PresentationURL, SerialNumber | Format-List
        Return $UPnPDevices
    }
  
    [string] GetNewAPIKey() {
        if ($this.RemoteApiAccessToken) {
            $ReqArgs = $this.BuildRequestParams('Put', '/0/config')
            $Result = Invoke-RestMethod @ReqArgs -Body '{ "linkbutton":true }'
        }
        $ReqArgs = $this.BuildRequestParams('Post', '')
        $Result = Invoke-RestMethod @ReqArgs -Body '{"devicetype":"PoSHue#PowerShell Hue"}'
        
        If ($Result[0].error) {
            Throw $Result[0].error.description
        }
        ElseIf ($Result[0].success) {
            # Assign the API Key and return it.
            $this.APIKey = $Result[0].success.username
            $this.ApiUri = "$($this.ApiUri)$($this.APIKey)"
            Return $Result[0].success.username
        }
        Else {
            Throw "There was an error.`r`n$Result"
        }
    }

    [array] GetLightNames() {
        $Result = $null
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/lights')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetLightNames(): An error occurred while getting light names.' + $_)
        }
        $Lights = $Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        Return $Lights.Value.Name
    }

    [PSCustomObject] GetAllLights() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        $Result = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/lights')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetAllLights(): An error occurred while getting light data.' + $_)
        }
        Return $Result
    }

    [PSCustomObject] GetAllLightsObject() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        $Result = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/lights')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetAllLightsObject(): An error occurred while getting light data.' + $_)
        }

        $CountLights = ($Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}).Count

        $Object = for ($i = 1; $i -lt $CountLights; $i++) {
            $Property = [ordered]@{
                Name         = $Result.$i.name
                Type         = $Result.$i.type
                IsOn         = $Result.$i.state.on
                Brightness   = $Result.$i.state.bri
                Hue          = $Result.$i.state.hue
                Saturation   = $Result.$i.state.sat
                ColourTemp   = $Result.$i.state.ct
                XY           = $Result.$i.state.xy
                ColorMode    = $Result.$i.state.colormode
                Reachable    = $Result.$i.state.reachable
                ModelId      = $Result.$i.modelid
                Manufacturer = $Result.$i.manufacturername
            }
            # Create the new object.
            New-Object -TypeName PSObject -Property $Property
        }

        Return $Object
    }

    [void] ToggleAllLights([LightState] $State) {
        # A simple toggle affecting all lights in the system.
        $Settings = @{}
        Switch ($State) {
            On {$Settings.Add("on", $true)}
            Off {$Settings.Add("on", $false)}
        }
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', '/groups/0/action')
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('ToggleAllLights([LightState] $State): An error occurred while toggling lights.' + $_)
        }

    }

    [void] SetHueScene([string] $SceneID) { 
        # Set a Hue Scene (collection of lights and their settings)   
        $Settings = @{}
        $Settings.Add("scene", $SceneID)

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', '/groups/0/action')
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueScene([string] $SceneID): An error occurred while setting a scene.' + $_)
        }
    }

    [PSCustomObject] GetAllGroups() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        $Result = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/groups')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetAllGroups(): An error occurred while getting group data.' + $_)
        }
        Return $Result
    }

    [PSCustomObject] GetAllSensors() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        $Result = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/sensors')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetAllSensors(): An error occurred while getting sensor data.' + $_)
        }
        Return $Result
    }


}

Class HueLight : HueFactory {

    ##############
    # PROPERTIES #
    ##############

    [ValidateLength(1, 2)][string] $Light
    [ValidateLength(2, 80)][string] $LightFriendlyName
    [ipaddress] $BridgeIP
    [ValidateLength(20, 50)][string] $APIKey
    [ValidateLength(1, 2000)][string] $JSON
    [bool] $On
    [ValidateRange(1, 254)][int] $Brightness
    [ValidateRange(0, 65535)][int] $Hue
    [ValidateRange(0, 254)][int] $Saturation
    [ValidateRange(153, 500)][int] $ColourTemperature
    [hashtable] $XY = @{ x = $null; y = $null }    
    [bool] $Reachable
    [string] $ApiUri
    [ValidateLength(20, 50)][string] $RemoteApiAccessToken
    [ColourMode] $ColourMode
    [AlertType] $AlertEffect

    # Useful for if you would like visible temp indicators
    hidden [hashtable] $ColourTemps = @{
        t5  = [System.Drawing.Color]::FromArgb(80, 181, 221)
        t6  = [System.Drawing.Color]::FromArgb(78, 178, 206)
        t7  = [System.Drawing.Color]::FromArgb(76, 176, 190)
        t8  = [System.Drawing.Color]::FromArgb(73, 173, 175)
        t9  = [System.Drawing.Color]::FromArgb(72, 171, 159)
        t10 = [System.Drawing.Color]::FromArgb(70, 168, 142)
        t11 = [System.Drawing.Color]::FromArgb(68, 166, 125)
        t12 = [System.Drawing.Color]::FromArgb(66, 164, 108)
        t13 = [System.Drawing.Color]::FromArgb(102, 173, 94)
        t14 = [System.Drawing.Color]::FromArgb(135, 190, 64)
        t15 = [System.Drawing.Color]::FromArgb(179, 204, 26)
        t16 = [System.Drawing.Color]::FromArgb(214, 213, 28)
        t17 = [System.Drawing.Color]::FromArgb(249, 202, 3)
        t18 = [System.Drawing.Color]::FromArgb(246, 181, 3)
        t19 = [System.Drawing.Color]::FromArgb(244, 150, 26)
        t20 = [System.Drawing.Color]::FromArgb(236, 110, 5)
        t21 = [System.Drawing.Color]::FromArgb(234, 90, 36)
        t22 = [System.Drawing.Color]::FromArgb(228, 87, 43)
        t23 = [System.Drawing.Color]::FromArgb(225, 74, 41)
        t24 = [System.Drawing.Color]::FromArgb(224, 65, 39)
        t25 = [System.Drawing.Color]::FromArgb(217, 55, 43)
        t26 = [System.Drawing.Color]::FromArgb(214, 49, 41)
        t27 = [System.Drawing.Color]::FromArgb(209, 43, 43)
        t28 = [System.Drawing.Color]::FromArgb(205, 40, 47)
        t29 = [System.Drawing.Color]::FromArgb(200, 36, 50)
        t30 = [System.Drawing.Color]::FromArgb(195, 35, 52)
    }

    
    ###############
    # CONSTRUCTOR #
    ###############

    HueLight([string] $Name, [ipaddress] $Bridge, [string] $APIKey) {
        $this.LightFriendlyName = $Name
        $this.BridgeIP = $Bridge
        $this.APIKey = $APIKey
        $this.ApiUri = "http://$($this.BridgeIP)/api/$($this.APIKey)"
        $this.Light = $this.GetHueLight($Name)
        $this.GetStatus()
    }

    # Constructor to return lights and names of lights remotely.
    HueLight([string] $Name, [string] $RemoteApiAcccessToken, [string] $APIKey, [bool] $RemoteSession) {
        $this.LightFriendlyName = $Name
        $this.RemoteApiAccessToken = $RemoteApiAcccessToken
        $this.APIKey = $APIKey
        $this.ApiUri = "{0}{1}" -f $this.HueRemoteApiUri, $this.APIKey
        $this.Light = $this.GetHueLight($Name)
        $this.GetStatus()
    }

    ###########
    # METHODS #
    ###########

    hidden [int] GetHueLight([string] $Name) {
        If (!($Name)) { Throw "No light name was specified." }
        # Change the named light in to the integer used by the bridge. We use this throughout.
        $HueData = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/lights')
            $HueData = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetHueLight([string] $Name): An error occurred while getting light information.' + $_)
        }
        $Lights = $HueData.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        $SelectedLight = $Lights | Where-Object {$_.Value.Name -eq $Name}  | Select-Object Name -ExpandProperty Name
        If ($SelectedLight) {
            Return $SelectedLight
        }
        Else {
            Throw "No light name matching `"$Name`" was found in the Hue Bridge.`r`nTry using [HueBridge]::GetLightNames() to get a full list of light names in this Hue Bridge."
        }
    }

    hidden [void] GetStatus() {
        # Get the current values of the State, Hue, Saturation, Brightness and Colour Temperatures
        $Status = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', "/lights/$($this.Light)")
            $Status = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetStatus(): An error occurred while getting the status of the light.' + $_)
        }

        $this.On = $Status.state.on
        
        # If Light is not reachable, set On = false
        if (!($status.state.reachable)) {$this.On = $status.state.reachable}        
        $this.Reachable = $Status.state.reachable
        
        # This is for compatibility reasons on Philips Ambient Lights
        if ($Status.state.bri -ge 1) {$this.Brightness = $Status.state.bri}

        $this.Hue = $Status.state.hue
        $this.Saturation = $Status.state.sat
        $this.ColourMode = $Status.state.colormode

        # This is for compatibility reasons on Philips Ambient Lights
        if ($Status.state.colormode -eq "xy") {
            $this.XY.x = $Status.state.xy[0]
            $this.XY.y = $Status.state.xy[1]
        }

        If ($Status.state.ct) {
            <#
            My Hue Go somehow got itself to a colour temp of "15" which is supposed 
            to be impossible. The [ValidateRange] of Colour Temp meant it wasn't possible
            to instantiate the [HueLight] class because it was outside the valid range of
            values accepted by the property. Makes sense but now means I need to handle
            possible impossible values. Added to the fact that this property might not
            exist on lights that don't support colour temperature, it's a bit of a pain.
            #>
            Switch ($Status.state.ct) {
                {($Status.state.ct -lt 153)} {$this.ColourTemperature = 153; break}
                {($Status.state.ct -gt 500)} {$this.ColourTemperature = 500; break}
                default {$this.ColourTemperature = $Status.state.ct}
            }
        }
        $this.AlertEffect = $Status.state.alert
    }

    # A simple toggle. If on, turn off. If off, turn on.
    [void] SwitchHueLight() {
        Switch ($this.On) {
            $false {$this.On = $true}
            $true {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueLight(): An error occurred while toggling the light.' + $_)
        }
    }

    # Set the state of the light. Always does what you give it, irrespective of the current setting.
    [void] SwitchHueLight([LightState] $State) {
        # An overload for SwitchHueLight
        Switch ($State) {
            On {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueLight([LightState] $State): An error occurred while switching the light .' + $_)
        }
    }

    # Set the state of the light (from off) for a transition - like a sunrise.
    [void] SwitchHueLight([LightState] $State, [bool] $Transition) {
        # An overload for SwitchHueLight
        Switch ($State) {
            On {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)
        If ($this.On -and $Transition) {
            $this.Brightness = 1
            $Settings.Add("bri", $this.Brightness)
        }

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueLight([LightState] $State, [bool] $Transition): An error occurred while toggling the light for transition.' + $_)
        }
    }

    ### Set the light's brightness value ###
    [string] SetHueLight([int] $Brightness) {
        # Set the brightness values of the light.
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Brightness."
        }
        $Result = $null

        $this.Brightness = $Brightness

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness): An error occurred while setting the light brightness.' + $_)
        }

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
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the brightness."}
    }

    ###############################################
    # Importance of colour settings: XY > CT > HS #
    ###############################################

    ### Set an XY value ###
    # Depends on the Gamut capability of the target Light
    # See: http://www.developers.meethue.com/documentation/hue-xy-values
    [string] SetHueLight([int] $Brightness, [float] $X, [float] $Y) {
        # Set brightness and XY values.
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Brightness and/or Colour Temperature."
        }
        $Result = $null
        $this.Brightness = $Brightness
        $this.XY.x = $X
        $this.XY.y = $Y

        $Settings = @{}
        $Settings.Add("xy", @($this.XY.x, $this.XY.y))
        $Settings.Add("bri", $this.Brightness)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)

        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness, [float] $X, [float] $Y): An error occurred while setting the light for XY.' + $_)
        }
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Brightness or XY colour value."}
    }

    ### Set a colour temperature ###
    [string] SetHueLight([int] $Brightness, [int] $ColourTemperature) {
        # Set the brightness and colour temperature of the light.
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Brightness and/or Colour Temperature."
        }

        If (!($this.ColourTemperature)) {
            Throw "Light named `"$($this.LightFriendlyName)`" does not hold the `"ct`" setting or it could not be read properly during`r`nobject instantiation. Does it support Colour Temperature? If so, please report a bug."
        }
        $Result = $null
        $this.Brightness = $Brightness
        $this.ColourTemperature = $ColourTemperature

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("ct", $this.ColourTemperature)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)

        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness, [int] $ColourTemperature): An error occurred while setting the light for CT.' + $_)
        }
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Brightness or Colour Temperature."}
    }

    ### Set an HSB value ###
    [string] SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation) {
        # Set the brightness, hue and saturation values of the light.
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Hue, Saturation and/or Brightness."
        }
        $Result = $null

        $this.Brightness = $Brightness
        $this.Hue = $Hue
        $this.Saturation = $Saturation

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("hue", $this.Hue)
        $Settings.Add("sat", $this.Saturation)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation): An error occurred while setting the light for HS.' + $_)
        }

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
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Hue, Saturation or Brightness."}
    }

    [void] Breathe([AlertType] $AlertEffect) {
        # Perform a breathe action on the light. Limited input values accepted, "none", "select", "lselect".
        $this.AlertEffect = $AlertEffect
        $Settings = @{}
        $Settings.Add("alert", [string] $this.AlertEffect)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('Breathe([AlertType] $AlertEffect): An error occurred while setting the breathe state.' + $_)
        }
    }

    # Set brightness and XY values with transition time.
    [string] SetHueLightTransition([int] $Brightness, [float] $X, [float] $Y, [uint16] $TransitionTime) {
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Brightness and/or Colour Temperature."
        }
        $Result = $null
        $this.Brightness = $Brightness
        $this.XY.x = $X
        $this.XY.y = $Y

        $Settings = @{}
        $Settings.Add("xy", @($this.XY.x, $this.XY.y))
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("transitiontime", $TransitionTime)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLightTransition([int] $Brightness, [float] $X, [float] $Y, [uint16] $TransitionTime): An error occurred while setting the light for XY transition.' + $_)
        }
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Brightness or XY colour value."}
    }

    # Set the brightness and colour temperature of the light with transition time
    [string] SetHueLightTransition([int] $Brightness, [int] $ColourTemperature, [uint16] $TransitionTime) {
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Brightness and/or Colour Temperature."
        }

        If (!($this.ColourTemperature)) {
            Throw "Light named `"$($this.LightFriendlyName)`" does not hold the `"ct`" setting or it could not be read properly during`r`nobject instantiation. Does it support Colour Temperature? If so, please report a bug."
        }
        $Result = $null
        $this.Brightness = $Brightness
        $this.ColourTemperature = $ColourTemperature

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("ct", $this.ColourTemperature)
        $Settings.Add("transitiontime", $TransitionTime)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLightTransition([int] $Brightness, [int] $ColourTemperature, [uint16] $TransitionTime): An error occurred while setting the light for CT transition.' + $_)
        }
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Brightness or Colour Temperature."}
    }

    [string] SetHueLightTransition([int] $Brightness, [int] $Hue, [int] $Saturation, [uint16] $TransitionTime) {
        # Set the brightness, hue and saturation values of the light.
        If (!($this.On)) {
            Throw "Light `"$($this.LightFriendlyName)`" must be on in order to set Hue, Saturation and/or Brightness."
        }
        
        $Result = $null
        $this.Brightness = $Brightness
        $this.Hue = $Hue
        $this.Saturation = $Saturation

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("hue", $this.Hue)
        $Settings.Add("sat", $this.Saturation)
        $Settings.Add("transitiontime", $TransitionTime)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/lights/$($this.Light)/state")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLightTransition([int] $Brightness, [int] $Hue, [int] $Saturation, [uint16] $TransitionTime): An error occurred while setting the light for HS transition.' + $_)
        }

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
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Hue, Saturation or Brightness."}
    }

    # Convert an RGB colour to XYZ format
    <#
        Don't use this straight conversion XY output to push to the light as it may be outside
        of the light's capabilities - it won't damage the light, the light will just
        make a bad guess. Use the output from this method and feed it through
        .xybForModel([hashtable] $ConvertedXYZ, [hashtable] $GamutTriangle)
        to get a colour and brightness more appropriate for your model/Gamut of luminaire.
        Yes, this could be improved by associating the model number with a Gamut
        triangle but this would require maintaining as often as Philips release
        new bulbs with different capabilities.
        For now, use the Gamut name identified from:
        http://www.developers.meethue.com/documentation/supported-lights
        (You need to register to see the list unfortunately)
        If you're asking yourself, what's a Gamut?! It's the ability of a bulb
        to reproduce a colour within the CIE colour spectrum. Some Gamuts aren't
        as wide.
        For example, the hue bulbs (Gamut B) are very good at showing nice whites,
        while the LivingColors (Gamut A) are generally a bit better at colours, like
        green and cyan. Newer models like the Hue Go and Hue LightStrips Plus use Gamut C.
    #>
    [hashtable] RGBtoXYZ([System.Drawing.Color] $Colour) {
        # Set up a return value [hashtable]
        $ret = @{}

        # Convert the RGB values to 0..1 values
        [float] $r = $Colour.R / 255
        [float] $g = $Colour.G / 255
        [float] $b = $Colour.B / 255

        # Gamma correction
        [float] $red = if ($r -gt [float]0.04045) { [Math]::Pow(($r + [float]0.055) / ([float]1.0 + [float]0.055), [float]2.4) } Else { ($r / [float]12.92) }
        [float] $green = if ($g -gt [float]0.04045) { [Math]::Pow(($g + [float]0.055) / ([float]1.0 + [float]0.055), [float]2.4) } Else { ($g / [float]12.92) }
        [float] $blue = if ($b -gt [float]0.04045) { [Math]::Pow(($b + [float]0.055) / ([float]1.0 + [float]0.055), [float]2.4) } Else { ($b / [float]12.92) }

        # Convert the RGB values to XYZ using the Wide RGB D65 conversion formula
        [float] $x = ($red * [float]0.664511) + ($green * [float]0.154324) + ($blue * [float]0.162028)
        [float] $y = ($red * [float]0.283881) + ($green * [float]0.668433) + ($blue * [float]0.047685)
        [float] $z = ($red * [float]0.000088) + ($green * [float]0.072310) + ($blue * [float]0.986039)

        # Create the return values
        [float] $ret.x = $x / ($x + $y + $z)
        [float] $ret.y = $y / ($x + $y + $z)
        [float] $ret.z = $z / ($x + $y + $z)

        If ($ret.x.ToString() -eq 'NaN') { $ret.x = [float]0.0 }
        If ($ret.y.ToString() -eq 'NaN') { $ret.y = [float]0.0 }
        If ($ret.z.ToString() -eq 'NaN') { $ret.z = [float]0.0 }

        Return $ret
    }

    <#
        Stores a set of Gamut values depicting the end points of a triangle
        corresponding to the Gamut of a bulb. The calculated XY values are compared
        with these points to see if the converted XY values fall within this triangle.
        If not, they're smoothed out by calculating the closest point.
    #>
    [hashtable] GamutTriangles([Gamut] $GamutID) {

        $GamutTriangles = @{
            GamutA       = @{
                Red   = @{ x = 0.704; y = 0.296 }
                Green = @{ x = 0.2151; y = 0.7106 }
                Blue  = @{ x = 0.138; y = 0.08 }
            }
            GamutB       = @{
                Red   = @{ x = 0.675; y = 0.322 }
                Green = @{ x = 0.409; y = 0.518 }
                Blue  = @{ x = 0.167; y = 0.04 }
            }
            GamutC       = @{
                Red   = @{ x = 0.692; y = 0.308 }
                Green = @{ x = 0.17; y = 0.7 }
                Blue  = @{ x = 0.153; y = 0.048 }
            }
            GamutDefault = @{
                Red   = @{ x = 1.0; y = 0.0 }
                Green = @{ x = 0.0; y = 1.0 }
                Blue  = @{ x = 0.0; y = 0.0 }
            }
        }

        Return $GamutTriangles."$GamutID"
    }


    hidden [float] crossProduct($p1, $p2) {
        Return [float]($p1.x * $p2.y - $p1.y * $p2.x)
    }

    hidden [bool] isPointInTriangle($p, [psobject]$triangle) {
        $red = $triangle.Red
        $green = $triangle.Green
        $blue = $triangle.Blue
    
        $v1 = @{
            x = $green.x - $red.x
            y = $green.y - $red.y
        }
        $v2 = @{
            x = $blue.x - $red.x
            y = $blue.y - $red.y
        }
        $q = @{
            x = $p.x - $red.x
            y = $p.y - $red.y
        }

        $s = ($this.crossProduct($q, $v2)) / ($this.crossProduct($v1, $v2))
        $t = ($this.crossProduct($v1, $q)) / ($this.crossProduct($v1, $v2))
        Return ($s -ge [float]0.0) -and ($t -ge [float]0.0) -and ($s + $t -le [float]1.0)
    }

    hidden [hashtable] closestPointOnLine($a, $b, $p) {
        $ap = @{
            x = $p.x - $a.x
            y = $p.y - $a.y
        }
        $ab = @{
            x = $b.x - $a.x
            y = $b.y - $a.y
        }
        [float] $ab2 = $ab.x * $ab.x + $ab.y * $ab.y
        [float] $ap_ab = $ap.x * $ab.x + $ap.y * $ab.y
        [float] $t = $ap_ab / $ab2
    
        if ($t -lt [float]0.0) {
            $t = [float]0.0;
        }
        elseif ($t -gt [float]1.0) {
            $t = [float]1.0;
        }

        return @{
            x = $a.x + $ab.x * $t
            y = $a.y + $ab.y * $t
        }
    }

    hidden [float] distance($p1, $p2) {
        [float] $dx = $p1.x - $p2.x
        [float] $dy = $p1.y - $p2.y
        [float] $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
        return $dist
    }

    [hashtable] xyForModel($xy, $Gamut) {
        $triangle = $this.GamutTriangles($Gamut)
        If ($this.isPointInTriangle($xy, $triangle)) {
            Return @{
                x = $xy.x
                y = $xy.y
            }
        }
        $pAB = $this.closestPointOnLine($triangle.Red, $triangle.Green, $xy)
        $pAC = $this.closestPointOnLine($triangle.Blue, $triangle.Red, $xy)
        $pBC = $this.closestPointOnLine($triangle.Green , $triangle.Blue, $xy)
        [float] $dAB = $this.distance($xy, $pAB)
        [float] $dAC = $this.distance($xy, $pAC)
        [float] $dBC = $this.distance($xy, $pBC)
        [float] $lowest = $dAB

        $closestPoint = $pAB
        If ($dAC -lt $lowest) {
            $lowest = $dAC
            $closestPoint = $pAC
        }
        If ($dBC -lt $lowest) {
            $lowest = $dBC
            $closestPoint = $pBC
        }
        Return $closestPoint;
    }

    [hashtable] xybForModel($ConvertedXYZ, $TargetGamut ) {
        $myxy = $this.xyForModel($ConvertedXYZ, $TargetGamut)
        $xyb = @{
            x = $myxy.x
            y = $myxy.y
            b = [int]($ConvertedXYZ.z * 255)
        }
        Return $xyb
    }

}

Class HueGroup : HueFactory {

    ##############
    # PROPERTIES #
    ##############

    [ValidateLength(1, 2)][string] $Group
    [ValidateLength(2, 80)][string] $GroupFriendlyName
    [ipaddress] $BridgeIP
    [ValidateLength(20, 50)][string] $APIKey
    [ValidateLength(1, 2000)][string] $JSON
    [bool] $On
    [ValidateRange(1, 254)][int] $Brightness
    [ValidateRange(0, 65535)][int] $Hue
    [ValidateRange(0, 254)][int] $Saturation
    [ValidateRange(153, 500)][int] $ColourTemperature
    [hashtable] $XY = @{ x = $null; y = $null }
    [ColourMode] $ColourMode
    [AlertType] $AlertEffect
    [array] $Lights
    [RoomClass] $GroupClass
    [string] $GroupType
    [bool] $AnyOn
    [bool] $AllOn
    [string] $ApiUri
    [ValidateLength(20, 50)][string] $RemoteApiAccessToken

    ###############
    # CONSTRUCTOR #
    ###############

    # Local constructor for new groups
    HueGroup([string] $Bridge, [string] $API) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
        $this.ApiUri = "http://$($this.BridgeIP)/api/$($this.APIKey)"
    }

    HueGroup([string] $Name, [string] $Bridge, [string] $API) {
        $this.GroupFriendlyName = $Name
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
        $this.ApiUri = "http://$($this.BridgeIP)/api/$($this.APIKey)"
        $this.Group = $this.GetLightGroup($Name)
        $this.GetStatus()
    }

    # Remote API constructor for creation of new groups.
    HueGroup([string] $RemoteApiAcccessToken, [string] $APIKey, [bool] $RemoteSession) {
        $this.RemoteApiAccessToken = $RemoteApiAcccessToken
        $this.APIKey = $APIKey
        $this.ApiUri = "{0}{1}" -f $this.HueRemoteApiUri, $this.APIKey
    }

    # Constructor to return lights and names of lights remotely.
    HueGroup([string] $Name, [string] $RemoteApiAcccessToken, [string] $APIKey, [bool] $RemoteSession) {
        $this.GroupFriendlyName = $Name
        $this.RemoteApiAccessToken = $RemoteApiAcccessToken
        $this.APIKey = $APIKey
        $this.ApiUri = "{0}{1}" -f $this.HueRemoteApiUri, $this.APIKey
        $this.Group = $this.GetLightGroup($Name)
        $this.GetStatus()
    }

    ###########
    # METHODS #
    ###########

    hidden [int] GetLightGroup([string] $Name) {
        If (!($Name)) { Throw "No group name was specified." }
        # Change the named group in to the integer used by the bridge. We use this throughout.
        $Result = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', "/groups")
            $Result = Invoke-RestMethod @ReqArgs
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('GetLightGroup([string] $Name): An error occurred while getting light information.' + $_)
        }
        $Groups = $Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        $SelectedGroup = $Groups | Where-Object {$_.Value.Name -eq $Name}  | Select-Object Name -ExpandProperty Name
        If ($SelectedGroup) {
            Return $SelectedGroup
        }
        Else {
            Throw "No group name matching `"$Name`" was found in the Hue Bridge.`r`nTry using [HueBridge]::GetLightGroups() to get a full list of groups in this Hue Bridge."
        }
    }

    [psobject] GetLightGroups() {
        # Get light groups.

        Try {
            $ReqArgs = $this.BuildRequestParams('Get', "/groups")
            $Result = Invoke-RestMethod @ReqArgs
            If ($Result.error) {
                Throw $Result.error
            }
            Return $Result
        }
        Catch {
            $this.ReturnError('GetLightGroups(): An error occurred while getting the light groups.' + "`n" + $_)
            Return $null
        }
    }

    [void] CreateLightGroup([string]$GroupName, [string[]] $LightID) {
        # Create a light group. A light can belong to multiple light groups.
        $Settings = @{}
        $Settings.Add("name", $GroupName)
        $Settings.Add("type", "LightGroup")
        $Settings.Add("lights", $LightID)

        Try {
            $ReqArgs = $this.BuildRequestParams('Post', "/groups")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('CreateLightGroup([string]$GroupName, [string[]] $LightID): An error occurred while creating the light group.' + "`n" + $_)
        }
        $this.GroupFriendlyName = $GroupName
        $this.Group = $this.GetLightGroup($this.GroupFriendlyName)
        $this.GetStatus()
    }

    [void] CreateLightGroup([string]$GroupName, [RoomClass]$RoomClass, [string[]] $LightID) {
        # Create a room type. Lights can only belong to one room.
        $Settings = @{}
        $Settings.Add("name", $GroupName)
        $Settings.Add("type", "Room")
        $Settings.Add("class", [string]$RoomClass)
        $Settings.Add("lights", $LightID)

        Try {
            $ReqArgs = $this.BuildRequestParams('Post', "/groups")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('CreateLightGroup([string]$GroupName, [RoomClass]$RoomClass, [string[]] $LightID): An error occurred while creating the group.' + "`n" + $_)
        }
        $this.GroupFriendlyName = $GroupName
        $this.Group = $this.GetLightGroup($this.GroupFriendlyName)
        $this.GetStatus()
    }

    [string] DeleteLightGroup([string]$GroupName) {
        # Delete a light group, whether a Room or LightGroup type.
        $Result = $null
        $this.GroupFriendlyName = $GroupName
        $this.Group = $this.GetLightGroup($GroupName)

        Try {
            $ReqArgs = $this.BuildRequestParams('Delete', "/groups/$($this.Group)")
            $Result = Invoke-RestMethod @ReqArgs
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('DeleteLightGroup([string]$GroupName): An error occurred while deleting the light group.' + "`n" + $_)
        }
        Return $Result.success
    }

    hidden [void] GetStatus() {
        # Get the current values of the State, Hue, Saturation, Brightness and Colour Temperatures
        If (!($this.Group)) { Throw "No group is specified." }
        $Status = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', "/groups/$($this.Group)")
            $Status = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetStatus(): An error occurred while getting the status of the group.' + $_)
        }

        $this.On = $Status.action.on
        $this.Brightness = $Status.action.bri
        $this.Hue = $Status.action.hue
        $this.Saturation = $Status.action.sat
        $this.ColourMode = $Status.action.colormode
        $this.XY.x = $Status.action.xy[0]
        $this.XY.y = $Status.action.xy[1]
        If ($Status.action.ct) {
            Switch ($Status.action.ct) {
                {($Status.action.ct -lt 153)} {$this.ColourTemperature = 153; break}
                {($Status.action.ct -gt 500)} {$this.ColourTemperature = 500; break}
                default {$this.ColourTemperature = $Status.action.ct}
            }
        }
        $this.AlertEffect = $Status.action.alert
        $this.Lights = $Status.lights
        $this.AllOn = $Status.state.all_on
        $this.AnyOn = $Status.state.any_on
        If ($Status.class) {
            $this.GroupClass = $Status.class
        }
        Else { $this.GroupClass = 'Other' }
        $this.GroupType = $Status.type
    }

    # A simple toggle. If on, turn off. If off, turn on.
    [void] SwitchHueGroup() {
        If (!($this.Group)) {
            Throw "This operation requires the Group (the identifying number of the group) property to be set.`nYou probably wanted to instantiate with the group name."
        }
        Switch ($this.On) {
            $false {$this.On = $true}
            $true {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }

        }
        Catch {
            $this.ReturnError('SwitchHueGroup(): An error occurred while toggling the group.' + $_)
        }
    }

    # Set the state of the light. Always does what you give it, irrespective of the current setting.
    [void] SwitchHueGroup([LightState] $State) {
        # An overload for SwitchHueLight
        If (!($this.Group)) {
            Throw "This operation requires the Group (the identifying number of the group) property to be set.`nYou probably wanted to instantiate with the group name."
        }
        Switch ($State) {
            On {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('SwitchHueGroup([LightState] $State): An error occurred while switching the group .' + $_)
        }
    }

    # Set the state of the light (from off) for a transition - like a sunrise.
    [void] SwitchHueGroup([LightState] $State, [bool] $Transition) {
        # An overload for SwitchHueLight
        If (!($this.Group)) {
            Throw "This operation requires the Group (the identifying number of the group) property to be set.`nYou probably wanted to instantiate with the group name."
        }
        Switch ($State) {
            On {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)
        If ($this.On -and $Transition) {
            $this.Brightness = 1
            $Settings.Add("bri", $this.Brightness)
        }

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }

        }
        Catch {
            $this.ReturnError('SwitchHueGroup([LightState] $State, [bool] $Transition): An error occurred while toggling the group for transition.' + $_)
        }
    }

    # Change the attributes of a group
    [void] EditHueGroup([string] $Name, [string[]] $LightIDs) { 
        If (!($this.Group)) { 
            Throw 'The group must exist and be defined in _this_ object before it can be changed. If you have not already, create the group or re-instantiate this object with an existing group name.'
        }
        
        $Settings = @{}
        $Settings.Add("name", $Name)
        $Settings.Add("lights", $LightIDs)

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
            If ($Result.error -ne $null) {
                Throw $Result.error
            }
            $this.GroupFriendlyName = $Name
            $this.Lights = $LightIDs
        }
        Catch {
            $this.ReturnError('EditHueGroup([string] $Name, [string[]] $LightIDs): An error occurred setting the group attributes/members.' + $_)
        }
    }

    ### Set an brightness value - good when you don't want to alter the entire group's colour settings. ###
    [string] SetHueGroup([int] $Brightness) {
        # Set the brightness values of all lights in the group.
        If (!($this.Group)) {
            Throw 'No group specified. Instantiate an existing group first.'
        }
        $Result = $null

        $this.Brightness = $Brightness

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueGroup([int] $Brightness): An error occurred while setting the group brightness.' + $_)
        }

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
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the brightness."}
    }


    ### Set an XY value ###
    # Depends on the Gamut capability of the target lights in the group
    # See: http://www.developers.meethue.com/documentation/hue-xy-values
    [string] SetHueGroup([int] $Brightness, [float] $X, [float] $Y) {
        # Set brightness and XY values.
        If (!($this.Group)) {
            Throw 'No group specified. Instantiate an existing group first.'
        }
        $Result = $null
        $this.Brightness = $Brightness
        $this.XY.x = $X
        $this.XY.y = $Y

        $Settings = @{}
        $Settings.Add("xy", @($this.XY.x, $this.XY.y))
        $Settings.Add("bri", $this.Brightness)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueGroup([int] $Brightness, [float] $X, [float] $Y): An error occurred while setting the group for XY.' + $_)
        }
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Brightness or XY colour value of the group."}
    }

    ### Set a colour temperature ###
    [string] SetHueGroup([int] $Brightness, [int] $ColourTemperature) {
        # Set the brightness and colour temperature of the lights in the group.
        If (!($this.Group)) {
            Throw 'No group specified. Instantiate an existing group first.'
        }

        $Result = $null
        $this.Brightness = $Brightness
        $this.ColourTemperature = $ColourTemperature

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("ct", $this.ColourTemperature)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueGroup([int] $Brightness, [int] $ColourTemperature): An error occurred while setting the group for colour temperature.' + $_)
        }
        If (($Result.success -ne $null) -and ($Result.error -eq $null)) {
            $this.GetStatus()
            Return "Success"
        }
        ElseIf ($Result.error -ne $null) {
            $Output = 'Error: '
            Foreach ($e in $Result) {
                Switch ($e.error.type) {
                    201 {$Output += $e.error.description}
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Brightness or Colour Temperature."}
    }

    ### Set an HSB value ###
    [string] SetHueGroup([int] $Brightness, [int] $Hue, [int] $Saturation) {
        # Set the brightness, hue and saturation values of the light.
        If (!($this.Group)) {
            Throw 'No group specified. Instantiate an existing group first.'
        }
        $Result = $null

        $this.Brightness = $Brightness
        $this.Hue = $Hue
        $this.Saturation = $Saturation

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("hue", $this.Hue)
        $Settings.Add("sat", $this.Saturation)
        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/groups/$($this.Group)/action")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueGroup([int] $Brightness, [int] $Hue, [int] $Saturation): An error occurred while setting the group for HSB.' + $_)
        }

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
                    default {$Output += "Unknown error: $($e.error.description)"}
                }
            }
            Throw $Output
        }
        Else {Throw "An error occurred setting the Hue, Saturation or Brightness."}
    }
}

Class HueSensor : HueFactory {

    ##############
    # PROPERTIES #
    ##############

    [ValidateLength(1, 2)][string] $Sensor
    [ValidateLength(2, 80)][string] $SensorFriendlyName
    [ipaddress] $BridgeIP
    [ValidateLength(20, 50)][string] $APIKey
    [psobject] $Data
    [string] $ApiUri
    [ValidateLength(20, 50)][string] $RemoteApiAccessToken

    ###############
    # CONSTRUCTOR #
    ###############

    HueSensor([ipaddress] $Bridge, [string] $API) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
        $this.ApiUri = "http://$($this.BridgeIP)/api/$($this.APIKey)"
    }

    HueSensor([string] $Name, [ipaddress] $Bridge, [string] $APIKey) {
        $this.SensorFriendlyName = $Name
        $this.BridgeIP = $Bridge
        $this.APIKey = $APIKey
        $this.ApiUri = "http://$($this.BridgeIP)/api/$($this.APIKey)"
        $this.Sensor = $this.GetHueSensor($Name)
        $this.GetStatus()
    }

    # Constructor to return lights and names of lights remotely.
    HueSensor([string] $Name, [string] $RemoteApiAcccessToken, [string] $APIKey, [bool] $RemoteSession) {
        $this.SensorFriendlyName = $Name
        $this.RemoteApiAccessToken = $RemoteApiAcccessToken
        $this.APIKey = $APIKey
        $this.ApiUri = "{0}{1}" -f $this.HueRemoteApiUri, $this.APIKey
        $this.Sensor = $this.GetHueSensor($Name)
        $this.GetStatus()
    }

    ###########
    # METHODS #
    ###########

    [PSCustomObject] GetAllSensors() {
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        $Result = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/sensors')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetAllSensors(): An error occurred while getting sensor data.' + $_)
        }
        Return $Result
    }

    [array] GetSensorNames() {
        $Result = $null
        If (!($this.APIKey)) {
            Throw "This operation requires the APIKey property to be set."
        }
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/sensors')
            $Result = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetSensorNames(): An error occurred while getting sensor names.' + $_)
        }
        $Sensors = $Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        Return $Sensors.Value.Name
    }

    # Gets a sensor's number from the Bridge.
    hidden [int] GetHueSensor([string] $Name) {
        If (!($Name)) { Throw "No sensor name was specified." }
        # Change the named sensor in to the integer used by the bridge. We use this throughout.
        $HueData = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', '/sensors')
            $HueData = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetHueSensor([string] $Name): An error occurred while getting sensor information.' + $_)
        }
        $Sensors = $HueData.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        $SelectedSensor = $Sensors | Where-Object {$_.Value.Name -eq $Name}  | Select-Object Name -ExpandProperty Name
        If ($SelectedSensor) {
            Return $SelectedSensor
        }
        Else {
            Throw "No sensor name matching `"$Name`" was found in the Hue Bridge `"$($this.BridgeIP)`".`r`nTry using [HueBridge]::GetSensorNames() to get a full list of sensor names in this Hue Bridge."
        }
    }

    # Gets a sensor's data.
    [void] GetStatus() {
        # Get the current values of the sensor data
        If (!($this.Sensor)) { Throw "No sensor is specified." }
        $Status = $null
        Try {
            $ReqArgs = $this.BuildRequestParams('Get', "/sensors/$($this.Sensor)")
            $Status = Invoke-RestMethod @ReqArgs
        }
        Catch {
            $this.ReturnError('GetStatus(): An error occurred while getting the status of the sensor.' + $_)
        }

        $this.Data = $Status        
    }

    # Sets a sensor either on or off
    [psobject] SwitchHueSensorState([bool] $State) {
        # Get the current values of the sensor data
        If (!($this.Sensor)) { Throw "No sensor is specified." }

        $Settings = @{}
        $Settings.Add("on", $State)
        $Result = $null

        Try {
            $ReqArgs = $this.BuildRequestParams('Put', "/sensors/$($this.Sensor)/config")
            $Result = Invoke-RestMethod @ReqArgs -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueSensorState([bool] $State): An error occurred while setting the sensor state.' + $_)
        }
        Return $Result
       
    }

}
