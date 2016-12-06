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

Class ErrorHandler {
    # Base class defining a method for error handling which we can extend
    # Return errors and terminates execution

    hidden [void] ReturnError([string] $e) {
        Write-Error $e -ErrorAction Stop
    }
}

Class HueBridge : ErrorHandler {
    ##############
    # PROPERTIES #
    ##############

    [ipaddress] $BridgeIP
    [ValidateLength(20,50)][string] $APIKey
    hidden [int] $GroupID

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
            Throw $Result[0].error.description
        }
        ElseIf ($Result[0].success) {
            # Assign the API Key and return it.
            $this.APIKey = $Result[0].success.username
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
            $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        }
        Catch {
            $this.ReturnError('GetLightNames(): An error occurred while getting light names.'+$_)
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
            $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        }
        Catch {
            $this.ReturnError('GetAllLights(): An error occurred while getting light data.'+$_)
        }
        Return $Result
    }

    [void] ToggleAllLights([LightState] $State) {
        # A simple toggle affecting all lights in the system.
        $Settings = @{}
        Switch ($State) {
            On  {$Settings.Add("on", $true)}
            Off {$Settings.Add("on", $false)}
        }
        Try {
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups/0/action" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('ToggleAllLights([LightState] $State): An error occurred while toggling lights.'+$_)
        }

    }

    [void] SetHueScene([string] $SceneID) { 
        # Set a Hue Scene (collection of lights and their settings)   
        $Settings = @{}
        $Settings.Add("scene", $SceneID)

        Try {
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups/0/action" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueScene([string] $SceneID): An error occurred while setting a scene.'+$_)
        }
    }

}

Class HueLight : ErrorHandler {

    ##############
    # PROPERTIES #
    ##############

    [ValidateLength(1,2)][string] $Light
    [ValidateLength(2,80)][string] $LightFriendlyName
    [ipaddress] $BridgeIP
    [ValidateLength(20,50)][string] $APIKey
    [ValidateLength(1,2000)][string] $JSON
    [bool] $On
    [ValidateRange(1,254)][int] $Brightness
    [ValidateRange(0,65535)][int] $Hue
    [ValidateRange(0,254)][int] $Saturation
    [ValidateRange(153,500)][int] $ColourTemperature
    [hashtable] $XY = @{ x = $null; y = $null }
    [ColourMode] $ColourMode
    [AlertType] $AlertEffect

    # Useful for if you would like visible temp indicators
    hidden [hashtable] $ColourTemps = @{
        t5 = [System.Drawing.Color]::FromArgb(80,181,221)
        t6 = [System.Drawing.Color]::FromArgb(78,178,206)
        t7 = [System.Drawing.Color]::FromArgb(76,176,190)
        t8 = [System.Drawing.Color]::FromArgb(73,173,175)
        t9 = [System.Drawing.Color]::FromArgb(72,171,159)
        t10 = [System.Drawing.Color]::FromArgb(70,168,142)
        t11 = [System.Drawing.Color]::FromArgb(68,166,125)
        t12 = [System.Drawing.Color]::FromArgb(66,164,108)
        t13 = [System.Drawing.Color]::FromArgb(102,173,94)
        t14 = [System.Drawing.Color]::FromArgb(135,190,64)
        t15 = [System.Drawing.Color]::FromArgb(179,204,26)
        t16 = [System.Drawing.Color]::FromArgb(214,213,28)
        t17 = [System.Drawing.Color]::FromArgb(249,202,3)
        t18 = [System.Drawing.Color]::FromArgb(246,181,3)
        t19 = [System.Drawing.Color]::FromArgb(244,150,26)
        t20 = [System.Drawing.Color]::FromArgb(236,110,5)
        t21 = [System.Drawing.Color]::FromArgb(234,90,36)
        t22 = [System.Drawing.Color]::FromArgb(228,87,43)
        t23 = [System.Drawing.Color]::FromArgb(225,74,41)
        t24 = [System.Drawing.Color]::FromArgb(224,65,39)
        t25 = [System.Drawing.Color]::FromArgb(217,55,43)
        t26 = [System.Drawing.Color]::FromArgb(214,49,41)
        t27 = [System.Drawing.Color]::FromArgb(209,43,43)
        t28 = [System.Drawing.Color]::FromArgb(205,40,47)
        t29 = [System.Drawing.Color]::FromArgb(200,36,50)
        t30 = [System.Drawing.Color]::FromArgb(195,35,52)
    }

    
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
        If (!($Name)) { Throw "No light name was specified." }
        # Change the named light in to the integer used by the bridge. We use this throughout.
        $HueData = $null
        Try {
            $HueData = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        }
        Catch {
            $this.ReturnError('GetHueLight([string] $Name): An error occurred while getting light information.'+$_)
        }
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
        $Status = $null
        Try {
            $Status = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)"
        }
        Catch {
            $this.ReturnError('GetStatus(): An error occurred while getting the status of the light.'+$_)
        }

        $this.On = $Status.state.on
        $this.Brightness = $Status.state.bri
        $this.Hue = $Status.state.hue
        $this.Saturation = $Status.state.sat
        $this.ColourMode = $Status.state.colormode
        $this.XY.x = $Status.state.xy[0]
        $this.XY.y = $Status.state.xy[1]
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
            $false  {$this.On = $true}
            $true {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)
        Try {
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueLight(): An error occurred while toggling the light.'+$_)
        }
    }

    # Set the state of the light. Always does what you give it, irrespective of the current setting.
    [void] SwitchHueLight([LightState] $State) { # An overload for SwitchHueLight
        Switch ($State) {
            On  {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        Try {
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueLight([LightState] $State): An error occurred while switching the light .'+$_)
        }
    }

    # Set the state of the light (from off) for a transition - like a sunrise.
    [void] SwitchHueLight([LightState] $State, [bool] $Transition) { # An overload for SwitchHueLight
        Switch ($State) {
            On  {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)
        If ($this.On -and $Transition) {
            $this.Brightness = 1
            $Settings.Add("bri", $this.Brightness)
        }

        Try {
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SwitchHueLight([LightState] $State, [bool] $Transition): An error occurred while toggling the light for transition.'+$_)
        }
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness, [float] $X, [float] $Y): An error occurred while setting the light for XY.'+$_)
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
                    default {$Output +=  "Unknown error: $($e.error.description)"}
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness, [int] $ColourTemperature): An error occurred while setting the light for CT.'+$_)
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
                    default {$Output +=  "Unknown error: $($e.error.description)"}
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation): An error occurred while setting the light for HS.'+$_)
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
                    default {$Output +=  "Unknown error: $($e.error.description)"}
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('Breathe([AlertType] $AlertEffect): An error occurred while setting the breathe state.'+$_)
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLightTransition([int] $Brightness, [float] $X, [float] $Y, [uint16] $TransitionTime): An error occurred while setting the light for XY transition.'+$_)
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
                    default {$Output +=  "Unknown error: $($e.error.description)"}
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLightTransition([int] $Brightness, [int] $ColourTemperature, [uint16] $TransitionTime): An error occurred while setting the light for CT transition.'+$_)
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
                    default {$Output +=  "Unknown error: $($e.error.description)"}
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
            $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
        }
        Catch {
            $this.ReturnError('SetHueLightTransition([int] $Brightness, [int] $Hue, [int] $Saturation, [uint16] $TransitionTime): An error occurred while setting the light for HS transition.'+$_)
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
                    default {$Output +=  "Unknown error: $($e.error.description)"}
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
        [float] $r = $Colour.R/255
        [float] $g = $Colour.G/255
        [float] $b = $Colour.B/255

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
            GamutA = @{
                Red = @{ x = 0.704; y = 0.296 }
                Green = @{ x = 0.2151; y = 0.7106 }
                Blue = @{ x = 0.138; y = 0.08 }
            }
            GamutB = @{
                Red = @{ x = 0.675; y = 0.322 }
                Green = @{ x = 0.409; y = 0.518 }
                Blue = @{ x = 0.167; y = 0.04 }
            }
            GamutC = @{
                Red = @{ x = 0.692; y = 0.308 }
                Green = @{ x = 0.17; y = 0.7 }
                Blue = @{ x = 0.153; y = 0.048 }
            }
            GamutDefault = @{
                Red = @{ x = 1.0; y = 0.0 }
                Green = @{ x = 0.0; y = 1.0 }
                Blue = @{ x = 0.0; y = 0.0 }
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
        $pBC = $this.closestPointOnLine($triangle.Green ,$triangle.Blue, $xy)
        [float] $dAB = $this.distance($xy, $pAB)
        [float] $dAC = $this.distance($xy, $pAC)
        [float] $dBC = $this.distance($xy, $pBC)
        [float] $lowest = $dAB

        $closestPoint = $pAB
        If($dAC -lt $lowest) {
            $lowest = $dAC
            $closestPoint = $pAC
        }
        If($dBC -lt $lowest) {
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
            b = [int]($ConvertedXYZ.z*255)
        }
        Return $xyb
    }

}

Class HueGroup : ErrorHandler {

    ##############
    # PROPERTIES #
    ##############

    [ValidateLength(1,2)][string] $Group
    [ValidateLength(2,80)][string] $GroupFriendlyName
    [ipaddress] $BridgeIP
    [ValidateLength(20,50)][string] $APIKey
    [ValidateLength(1,2000)][string] $JSON
    [bool] $On
    [ValidateRange(1,254)][int] $Brightness
    [ValidateRange(0,65535)][int] $Hue
    [ValidateRange(0,254)][int] $Saturation
    [ValidateRange(153,500)][int] $ColourTemperature
    [hashtable] $XY = @{ x = $null; y = $null }
    [ColourMode] $ColourMode
    [AlertType] $AlertEffect

    ###############
    # CONSTRUCTOR #
    ###############

    HueGroup([ipaddress] $Bridge, [string] $API) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
    }

    HueGroup([string] $Name, [ipaddress] $Bridge, [string] $API) {
        $this.GroupFriendlyName =  $Name
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
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
            $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups"
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('GetLightGroup([string] $Name): An error occurred while getting light information.'+$_)
        }
        $Groups = $Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        $this.Group = $Groups | Where-Object {$_.Value.Name -match $Name}  | Select Name -ExpandProperty Name
        If ($this.Group) {
            Return $this.Group
        }
        Else {
            Throw "No group name matching `"$Name`" was found in the Hue Bridge `"$($this.BridgeIP)`".`r`nTry using [HueBridge]::GetLightGroups() to get a full list of groups in this Hue Bridge."
        }
    }

    [psobject] GetLightGroups() {
        # Get light groups.

        Try {
            $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups"
            If ($Result.error) {
                Throw $Result.error
            }
            Return $Result
        }
        Catch {
            $this.ReturnError('GetLightGroups(): An error occurred while getting the light groups.'+"`n"+$_)
            Return $null
        }
    }

    [void] CreateHueRoom([string]$GroupName, [RoomClass]$RoomClass, [string[]] $LightID) {
        # Create a room type.
        $Settings = @{}
        $Settings.Add("name", $GroupName)
        $Settings.Add("type", "Room")
        $Settings.Add("class", [string]$RoomClass)
        $Settings.Add("lights", $LightID)

        Try {
            $Result = Invoke-RestMethod -Method Post -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups" -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('CreateHueRoom([string]$GroupName, [RoomClass]$RoomClass, [string[]] $LightID): An error occurred while creating the group.'+"`n"+$_)
        }
    }

    [void] CreateLightGroup([string]$GroupName, [string[]] $LightID) {
        # Create a light group.
        $Settings = @{}
        $Settings.Add("name", $GroupName)
        $Settings.Add("type", "LightGroup")
        $Settings.Add("lights", $LightID)

        Try {
            $Result = Invoke-RestMethod -Method Post -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups" -Body (ConvertTo-Json $Settings)
            If ($Result.error) {
                Throw $Result.error
            }
        }
        Catch {
            $this.ReturnError('CreateLightGroup([string]$GroupName, [string[]] $LightID): An error occurred while creating the light group.'+"`n"+$_)
        }
    }

    hidden [void] GetStatus() {
        # Get the current values of the State, Hue, Saturation, Brightness and Colour Temperatures
        If (!($this.Group)) { Throw "No group is specified." }
        $Status = $null
        Try {
            $Status = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/groups/$($this.Group)"
        }
        Catch {
            $this.ReturnError('GetStatus(): An error occurred while getting the status of the group.'+$_)
        }

        $this.On = $Status.action.on
        $this.Brightness = $Status.action.bri
        $this.Hue = $Status.action.hue
        $this.Saturation = $Status.action.sat
        $this.ColourMode = $Status.action.colormode
        $this.XY.x = $Status.action.xy[0]
        $this.XY.y = $Status.action.xy[1]
        If ($Status.action.ct) {
            <#
            My Hue Go somehow got itself to a colour temp of "15" which is supposed 
            to be impossible. The [ValidateRange] of Colour Temp meant it wasn't possible
            to instantiate the [HueLight] class because it was outside the valid range of
            values accepted by the property. Makes sense but now means I need to handle
            possible impossible values. Added to the fact that this property might not
            exist on lights that don't support colour temperature, it's a bit of a pain.
            #>
            Switch ($Status.action.ct) {
                {($Status.action.ct -lt 153)} {$this.ColourTemperature = 153; break}
                {($Status.action.ct -gt 500)} {$this.ColourTemperature = 500; break}
                default {$this.ColourTemperature = $Status.action.ct}
            }
        }
        $this.AlertEffect = $Status.action.alert
    }

}