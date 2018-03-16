# Don't run this whole script blindly, the commands here are examples.
Add-Type -AssemblyName System.Drawing

# Import the [HueBridge] and [HueLight] classes
# so you can interact with them in your script.
Import-Module ".\PoSHue.psd1"
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

$Bridge.GetAllLightsObject()

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
$Light.SwitchHueLight("Off")
$Light.SwitchHueLight("On")

# In a Try Catch block, set the Brightness to 100, keep the existing hue and saturation
Try { 
    $Light.SetHueLight(100, $Light.Hue, $Light.Saturation)
}
Catch {
    "Wasn't able to set the light HSB $_"
}

# Set the light to 100 brightness (out of 254), 25500 hue (Green), 254 saturation (Maximum Colour)
$Light.SetHueLight(100, 25500, 254)

# Set the Brightness to 50, keep the existing colour temp
$Light.SetHueLight(50, $Light.ColourTemperature)

# Set the Brightness to 100, set colour temp to 370
$Light.SetHueLight(100, 370)

# Perform a single Breathe action.
$Light.Breathe("select")

# Set the light to 100 brightness (out of 254), 25500 hue (Green), 254 saturation (Maximum Colour), transition for 5 seconds
$Light.SetHueLightTransition(100, 25500, 254, 50)

# Set the Brightness to 50, keep the existing colour temp, transition for 5 seconds
$Light.SetHueLightTransition(50, $Light.ColourTemperature, 50)

# Set the Brightness to 100, set colour temp to 370, transition for 5 seconds
$Light.SetHueLightTransition(100, 370, 50)

# Breathe for 15 seconds.
$Light.Breathe("lselect")

# Just see what the object properties are.
$Light

# Convert Royal Blue RGB to XY values for a Gamut C lamp
$XYZ = $Office.RGBtoXYZ([System.Drawing.Color]$RGB) # Convert the RGB temperature colour with gamma correction
$XYB = $Office.xybForModel($XYZ, 'GamutC') # Get the X, Y and Brightness for a model with GamutC (Hue Go)
$Office.SetHueLight(150, $XYB.x, $XYB.y, 20) # Set the light to transition (over 2 seconds) to the RGB temperature value and set a brightness of 150 (out of 255).
