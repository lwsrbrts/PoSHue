# Don't run this whole script blindly, the commands here are examples.

# Import the [HueBridge] and [HueLight] classes
# so you can interact with them in your script.
Import-Module ".\PoSHue.ps1"
#Import-Module "$PSScriptRoot\PoSHue.ps1"

# Hue Bridge IP address
# You could use [HueBridge]::FindHueBridge() if you don't know your
# Hue Bridge IP address.
$Endpoint = "192.168.1.12"

# The APIKey/username created on the bridge
# If you don't have one yet, don't panic, the first section
# below shows you how to get one.
$UserID = "38cbd1cbcac542f9c26ad393739b7"

#####################
# [HueBridge] Class #
#####################

# OPTION 1

# Instantiate a Bridge class using just its IP address.
# Use this when you don't have a username to use with the
# [HueLight] class.
$Bridge = [HueBridge]::New($Endpoint)

# Get a new APIKey/username from the Bridge.
# Press the link button. If you don't, you'll get an error.
# Returns a [string]
$Bridge.GetNewAPIKey()

# If desired, you can now get a list of lights since the new
# APIKey/username you just got is set in the object now.
$Bridge.GetLightNames()

# OPTION 2

# Instantiate a Bridge class using its IP address and an
# APIKey/username.
# Use this when you have an APIKey/username and want a list
# of Hue Lights registered to the Bridge.
$Bridge = [HueBridge]::New($Endpoint, $UserID)

# Get an object containing all of the lights information
# from the bridge. Helps you check the current actual status
# of lights and their settings.
$Bridge.GetAllLights()

# Get a list of friendly names of Hue Lights registered to the bridge.
# Returns an [array] object of the light's names.
$Bridge.GetLightNames()

# Turns all lights on the bridge on, or off, depending on their
# current state.
$Bridge.ToggleAllLights()

####################
# [HueLight] Class #
####################

# The name of the light (obtained from [HueBridge]::GetLightNames())
$LightName = "Hue go 1"

# Instantiate a Hue Light object
# Use this constructor to get a reference to an actual light.
$Light = [HueLight]::New($LightName, $Endpoint, $UserID)

# Just see what the HueLight object's properties are.
$Light

# Toggle the light on or off
$Light.SwitchHueLight()
$Light.SwitchHueLight("On")
$Light.SwitchHueLight("Off")

# Set the Brightness to 100, keep the existing hue and saturation
Try { 
    $Light.SetHueLight(100, $Light.Hue, $Light.Saturation)
}
Catch {
    "Wasn't able to set the light HSB $_"
}

# Set the Brightness to 50, keep the existing colour temp
$Light.SetHueLight(50, $Light.ColourTemperature)

# Set the Brightness to 100, set colour temp to 370
$Light.SetHueLight(100, 500)

# Perform a single Breathe action.
$Light.Breathe("select")

# Breathe for 15 seconds.
$Light.Breathe("lselect")

# Just see what the object properties are.
$Light
