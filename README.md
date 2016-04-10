# PoSHue
A couple of PowerShell classes (no, really) that assist in getting simpler access to Philips Hue Luminaires using the REST API of the Hue Bridge.

## Why?
I have a few Philips Hue Luminaires (Beyond Lamp, Hue Go and Bloom) and I wanted a way of controlling them using PowerShell but fiddling with JSON every time I wanted to control them seemed a bit verbose. I've boiled down the basic actions to make it simple to use PowerShell to access the RESTful API on the bridge.

## Go on then, how do I use it?
### Pre-requisites
 * [WMF/PowerShell 5.0](https://www.microsoft.com/en-us/download/details.aspx?id=50395) (this went RTM (again) on 24th February 2016)
 * You only need the [`PoSHue.ps1`](../master/PoSHue.ps1) file. It contains the classes you'll use.
   * *I provide [`RGBtoXY.ps1`](../master/RGBtoXY.ps1) as a standalone, easy to understand and run script file for the benefit of people looking to get an XY value from an RGB colour. This file is **not** required for the class to work.* 
 * You need to be on your LAN with the Hue Bridge, obviously.

---

### Using it
Copy the [`PoSHue.ps1`](../master/PoSHue.ps1) file to the same folder as your script (or somewhere else if you want!) and use `Import-Module` on its location. See `Using-PoSHue.ps1` for an example or scroll to the very end of this read me for an end-to-end example script.
####First lines
Your starting script looks as follows.
```powershell
Add-Type -AssemblyName System.Drawing # Required or you'll get a parser error.
Import-Module .\PoSHue.ps1 # Assumes PoSHue.ps1 is saved in the same folder as your script!
```
>###Why is Add-Type needed?!
With the recent (8th April 2016) introduction of a collection of methods to convert RGB to XY, one of the methods relies on the use of the `System.Drawing` assembly and its associated `[System.Drawing.Color]` type. This assembly **must** be loaded before the class is imported. I am working to understand how best to overcome this (if indeed it can be at all) but for now, all scripts that will import the `PoSHue.ps1` file (classes) must have the following before the import or you will receive a parse error saying the `[System.Drawing.Color]` type can't be found.
```powershell
Add-Type -AssemblyName System.Drawing
```

---

#### HueBridge Class
Let's start with the `[HueBridge]` class. Use this to get an APIKey/username from your bridge so you can get and set light data with it using the `[HueLight]` class later.
 1. Get the IP address of your Bridge. The `[HueBridge]` class contains a static method (this means you can call it without instantiating the class) called `.FindHueBridge()`.
 2. Run
 
 ```powershell
 PS C:\>[HueBridge]::FindHueBridge()
 ```
 3. Your computer will perform a search. The search is synchronous (means you need to wait for it to complete) and takes about 15-20 seconds to finish. The method finds all UPnP devices described as "Hue" on your LAN (Subnet) and returns those as a list, giving you the IP of your bridge. One might argue this should happen by default, after all, the Hue Bridge IP address may change in a DHCP network. Two reasons why I don't do this automagically: 1. Who says this is the only Hue Bridge in the network? 2. The method call is a blocking action and I've not tried to get PowerShell to do stuff asynchronously with a callback yet.
 4. Instantiate a `[HueBridge]` class using your discovered (or known) Bridge IP address. Substitue your own bridge's IP address obviously.
 
 ```powershell
 PS C:\>$Bridge = [HueBridge]::New('192.168.1.12')
 ```
 5. Get the properties of the Bridge object.
 
 ```powershell
 PS C:\>$Bridge
 ```
 6. You'll see just the IP address property for now.
 7. Get a new APIKey (username) for the bridge. This is what you use to authenticate with the bridge to get and set information about the lights. The only way to get the key is to press the link button on your bridge and then ask for an APIKey/username.
 8. Press the link button on the bridge then run:
 
 ```powershell
 PS C:\>$Bridge.GetNewAPIKey()
 ```
 9. You should get a string of digits back. Record these for further use (with the `[HueLight]` class). Pressing the link button on the Bridge might get tedious! You're automating, remember. :)
 10. Now that you have an APIKey/username stored in your bridge object, go ahead and get a list of the lights on the Bridge using:
 
 ```powershell
 PS C:\>$Bridge.GetLightNames()
 ```
 11. You should see a list (an array) of lights registered to the bridge. The Bridge uses numbers to refer to the lights - we humans aren't great at associating numbers with objects so I use the names of the lights. The `[HueLight]` class also uses names instead of numbers.
 12. If you call `$Bridge` again by itself, you'll see the `APIKey` property there too. Remember, save this somewhere.
 13. If you already have an APIKey/username, you can instantiate the `[HueBridge]` class with that in order to use the `.GetLightNames()` method to get the names of the lights on the bridge. Something like: 
 
 ```powershell
 PS C:\>$Bridge = [HueBridge]::New('192.168.1.12', '38cbd1cbcac542f9c26ad393739b7')
 ```
 14. If you are struggling with something or want to get an unabashed set of data (as a PowerShell `[PSObject]`) about your lights from the bridge, use:
 
 ```powershell
 PS C:\>$Bridge.GetAllLights()
 ```
 
 15. If you just want to turn all Hue Lights on or off (all lights will become the same state). Use:
  ```powershell
 PS C:\>$Bridge.ToggleAllLights("On")
 PS C:\>$Bridge.ToggleAllLights("Off")
  ```

---

#### HueLight Class
The HueLight class allows you to set properties of a light (the interesting stuff!) like Brightness, Hue & Saturation and Colour Temperature. When you instantiate the `[HueLight]` class, you do so by providing the IP Address of your bridge, the APIKey/username and the name of the Hue Light you want to control.
There are obviously some restrictions on what values you can set for the light and these restrictions are imposed using the object's properties. These are limits imposed by the capabilities of the hardware rather than me, I just repeat those limits within the code.
 1. Instantiate the `[HueLight]` class, providing the necessary details. Obviously you can specify these as variables if you like.
 
 ```powershell
 PS C:\>$Light = [HueLight]::New('Hue go 1', '192.168.1.12', '38cbd1cbcac542f9c26ad393739b7')
 ```
 2. Call the object to see its properties.
 
 ```powershell
 PS C:\>$Light
 
 Light             : 4
 LightFriendlyName : Hue go 1
 BridgeIP          : 192.168.1.12
 APIKey            : 38cbd1cbcac542f9c26ad393739b7
 JSON              : 
 On                : True
 Brightness        : 102
 Hue               : 8378
 Saturation        : 144
 ColourTemperature : 370
 ColourMode        : ct
 
 ```
 3. As part of instantiating/constructing the `$Light` object, the `[HueLight]` class gets the existing *state* of the light from the Bridge. It sets values like **On** (whether the light is on or off), **Brightness**, **Hue**, **Saturation** and **Colour Temperature**. When you change these values using the methods described below, the object's properties are also updated and you can use these as you see fit.
 4. Now you have the `$Light` object (which is a Hue Light on your Bridge). Use any of the methods defined in the class to control it. To get a full list, either use IntelliSense or consult the class itself. The most useful methods are described below.

Here's a quick GIF of the process in just four lines.
![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/HueLight.gif "HueLight class in action.")

---

####Toggle the light on or off:
 **Syntax**
 ```powershell
 [void] SwitchHueLight()
 ```
 **Usage**
```powershell
 PS C:\>$Light.SwitchHueLight() # Returns nothing (light toggles)
 ```
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/switchhuelight.gif "SwitchHueLight()")
 ---
 
####Set the state of the light:
 **Syntax**
  ```powershell
 [void] SwitchHueLight([LightState] $State)
  ```

 **Usage**
 ```powershell
 PS C:\>$Light.SwitchHueLight("On") # Returns nothing (light switches on)
 PS C:\>$Light.SwitchHueLight("Off") # Returns nothing (light switches off)
 ```
 ---
 
####Specify the Brightness and XY co-ordinate values
*I capitulated and included an XY method to take advantage of RGB to XY conversion. The conversion to get from RGB to an XY value in the correct colour Gamut for a specific model is quite involved so I have included more detailed steps for this method in an additional section below.*
 
 **Syntax:**
 ```powershell
 [string] SetHueLight([int] $Brightness, [float] $X, [float] $Y)
 ```
 
 **Usage:**
 ```powershell
 PS C:\>$Light.SetHueLight(150, 0.4123, 0.1348) # Returns [string] Success
 ```
  ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/sethuelightxy.gif "SetHueLight()")
---
 
####Specify the Brightness and/or Colour Temperature
Not all Hue Lights support colour temperature - the class looks for the CT attribute, if it doesn't exist, this method will return an error advising that the lights does not hold this setting and it therefore cannot be set.

 **Syntax**
 ```powershell
 [string] SetHueLight([int] $Brightness, [int] $ColourTemperature)
 ```
 **Usage**
 ```powershell
 PS C:\>$Light.SetHueLight(150, 380) # Returns [string] Success
 ```
  ---
 
####Specify the Brightness and/or Hue and/or Saturation
**Syntax** 
```powershell
[string] SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation)
```
**Usage**
```powershell
PS C:\>$Light.SetHueLight(150, 45500, 150) # Returns [string] Success
```
---
  
####Perform a Breathe action

From Philips' own API documentation:

> The alert effect, which is a temporary change to the bulb’s state. This can take one of the following values:<br/>"none" – The light has no alert effect.<br/>"select" – The light performs one breathe cycle.<br/>"lselect" – The light performs breathe cycles for 15 seconds or until an "alert": "none" command is received.<br/>Note that this contains the last alert sent to the light and **not** its current state. i.e. After the breathe cycle has finished the bridge does not reset the alert to "none".

**Syntax**
```powershell
[void] Breathe([AlertType] $AlertEffect)
```
**Usage**
```powershell
PS C:\>$Light.Breathe(select) # Returns nothing (the light performs a single breathe)
```
---
####Change Brightness and/or XY values with transition
Change the brightness and/or XY values over a defined period of time in multiples of 100 milliseconds.
A transitiontime of 10 is therefore 1 second. Eg. `10 x 100ms = 1000ms` (1s)<br/>
A transition time of 300 is 30 seconds. Eg. `300 x 100ms = 30000ms` (30s)

**Syntax**
```powershell
[string] SetHueLightTransition([int] $Brightness, [float] $X, [float] $Y, [uint16] $TransitionTime)
```
**Usage**
```powershell
PS C:\>$Light.SetHueLightTransition(102, 0.1649, 0.1338, 20) # Returns [string] Success
```
---
####Change Brightness and/or colour temperature with transition
Change the brightness and/or colour temperature over a defined period of time in multiples of 100 milliseconds.
A transitiontime of 10 is therefore 1 second. Eg. `10 x 100ms = 1000ms` (1s)<br/>
A transition time of 300 is 30 seconds. Eg. `300 x 100ms = 30000ms` (30s)

**Syntax**
```powershell
[string] SetHueLightTransition([int] $Brightness, [int] $ColourTemperature, [uint16] $TransitionTime)
```
**Usage**
```powershell
PS C:\>$Light.SetHueLightTransition(200, 390, 20) # Returns [string] Success
```
---
####Change Brightness and/or Hue and/or Saturation with transition
Change the brightness and/or Hue and/or Saturation over a defined period of time in multiples of 100 milliseconds.
A transitiontime of 10 is therefore 1 second. Eg. `10 x 100ms = 1000ms` (1s)<br/>
A transition time of 300 is 30 seconds. Eg. `300 x 100ms = 30000ms` (30s)

**Syntax**
```powershell
[string] SetHueLightTransition([int] $Brightness, [int] $Hue, [int] $Saturation, [uint16] $TransitionTime)
```
**Usage**
```powershell
PS C:\>$Light.SetHueLightTransition(150, 45500, 254, 300) # Returns [string] Success
```
---
###Retaining current settings
To retain the same settings for one or more property such as Brightness, just use the existing property of the object and essentially, set it again.

For example, the following command would retain the same colour temperature as already set in the object but set the brightness to 50:

```powershell
PS C:\>$Light.SetHueLight(50, $Light.ColourTemperature)
```
If you then wanted to change the Colour Temperature to 370 but retain the Brightness as 50 you would do: 

```powershell
PS C:\>$Light.SetHueLight($Light.Brightness, 370) # Returns [string] Success
```
Notice that the colour mode changes from XY to CT in the following demo.
![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/sethuelightusingvars2.gif "SetHueLight()")

--- 
###Converting RGB to XY & Brightness
Here's an example of using the `[HueLight]` class to convert from RGB to XY.
Philips' own API documentation states that the correct XY value for Royal Blue (`RGB: 63, 104, 224`) on a Gamut C lamp such as the Hue Go is `[x:0.1649, y:0.1338]`. I have tested the conversion pretty extensively for RGB values across the range and for each of the Colour Gamuts covered by Philips' different models as defined on [this page at Philips](http://www.developers.meethue.com/documentation/hue-xy-values) and they're accurate. I have of course also tested on my own Hue Go and they're accurately reproduced.
The following is an example of using the RGBtoXYZ (and subsequently xybForModel) method to get a smoothed value for use with your own lamp.
 
```powershell
$RGB = [System.Drawing.Color]::FromArgb(63,104,224) # Define the RGB colour to convert from
$XYZ = $Light.RGBtoXYZ($RGB) # Convert the colour with gamma correction
$XYB = $Light.xybForModel($XYZ, 'GamutC') # Get the X, Y and Brightness for a model with GamutC (Hue Go)
$XYB
<#
Name                           Value
----                           -----
y                              0.13384
b                              179
x                              0.1648863
#>
```

I would now use this as follows - the parameters passed to `SetHueLight()` cause the method to work out which overload to use. If the XY values are not valid floats, define them as such when submitting them if necessary as follows:

```powershell
PS C:\>$Light.SetHueLight([int] $XYB.b, [float] $XYB.x, [float] $XYB.y) # Returns Success
```
#### How do I know what Gamut my lamp/bulb is?!
For some reason, Philips hide this information behind a login page on their Hue developer site. I imagine they wouldn't be pleased if I reproduced it here so I'll [just provide a link instead](http://www.developers.meethue.com/documentation/supported-lights). I'm sure a Google search will turn up the information you need also. Valid Gamut values for use in the `.xybForModel()` method are obtained from the `[Gamut]` enumeration, these are: `GamutA` | `GamutB` | `GamutC` | `GamutDefault` | 


## End to end basic example
The following example uses the `[HueLight]` class to turn on the lamp called Hue go 2 if it isn't already on and then sets an RGB colour (Royal Blue) by converting it to XY and finally sending the command to the light (via the bridge).
```powershell
Add-Type -AssemblyName System.Drawing # Required or you'll get a parser error!
Import-Module .\PoSHue.ps1 # Assumes PoSHue.ps1 is in the same folder as your script.

$Endpoint = "192.168.1.12" # IP Address of your Hue Bridge.
$UserID = "38cbd1cbcac542f9c26ad393739b7" # API "key" / password / username obtained from Hue.

# Instantiate the class and assign to the $Office variable
$Office = [HueLight]::new("Hue go 2", $Endpoint, $UserID)

# If the lamp isn't already on, turn it on.
If ($Office.On -ne $true) {
    $Office.SwitchHueLight("on")
}

# Royal Blue colour in RGB format
$RGB = [System.Drawing.Color]::FromArgb(63,104,224) # Define the RGB colour to convert from

# Convert the RGB for a Gamut C lamp.
$XYZ = $Office.RGBtoXYZ($RGB) # Convert the colour with gamma correction
$XYB = $Office.xybForModel($XYZ, 'GamutC') # Get the X, Y and Brightness for a model with GamutC (Hue Go)

# Set the XY value on the light.
$Office.SetHueLight($XYB.b,$XYB.x,$XYB.y)

# Done!
```
## End to end advanced example
The following example uses a class from my other project (PoSHive - to control your British Gas Hive heating system with PowerShell) to get the internal temperature inside the house and, using the Hive website's RGB values for temperatures (stored in the `[Hive]` class), temporarily transition the target light to the associated colour (of the temperature) and back again.
```powershell
Add-Type -AssemblyName System.Drawing # Required or you'll get a parser error!

Import-Module .\PoSHive.ps1 -ErrorAction Stop # Assumes PoSHive.ps1 is in the same folder as your script.
Import-Module .\PoSHue.ps1 -ErrorAction Stop # Assumes PoSHue.ps1 is in the same folder as your script.

$Endpoint = "192.168.1.12" # IP Address of your Hue Bridge.
$UserID = "38cbd1cbcac542f9c26ad393739b7" # API "key" / password / username obtained from Hue.

$HiveUsername = 'user@domain.com' # Hive website username
$HivePassword = '[hive website password]' # Hive website password

$Hive = [Hive]::new($HiveUsername, $HivePassword) # Instantiate the [Hive] class
$Hive.Login() # Log in to the Hive site.

$Temp = [Math]::Round($Hive.GetTemperature($false)) # Get the temperature from the Hive, round it to a whole number

Write-Output "Hive temperature is: $Temp" # Send back information about the current temp to console.

$RGB = $Hive.ColourTemps.Item("t$Temp") # Extract the associated RGB value for a colour temperature (in celsius) from the Hive class.

$Hive.Logout() # Log out from the Hive website - do this, it's a good thing!

$Office = [HueLight]::new("Hue go 2", $Endpoint, $UserID) # Instantiate the HueLight class
If ($Office.On -ne $true) { 
    $Office.SwitchHueLight("on") # If the light isn't on, turn it on first.
}

$OriginalX = $Office.XY.x # Store the original values of the light's current X value (to restore later)
$OriginalY = $Office.XY.y # Store the original values of the light's current Y value (to restore later)

$XYZ = $Office.RGBtoXYZ([System.Drawing.Color]$RGB) # Convert the RGB temperature colour with gamma correction
$XYB = $Office.xybForModel($XYZ, 'GamutC') # Get the X, Y and Brightness for a model with GamutC (Hue Go)

$TransitionTime = New-TimeSpan -Seconds 2 # Create a timespan of 2 seconds

$Office.SetHueLightTransition(150, $XYB.x, $XYB.y, ($TransitionTime.TotalMilliseconds/100)) # Set the light to transition (over 2 seconds) to the RGB temperature value and set a brightness of 150 (out of 255).

Start-Sleep -Seconds $TransitionTime.TotalSeconds # Sleep (to allow the light to finish its transition!

$Office.SetHueLightTransition(150,$OriginalX,$OriginalY, ($TransitionTime.TotalMilliseconds/100)) # Return the light to its previous colour setting.

# Done!

```
---
# Any questions?
No? Good. Seriously though, this is a starter for 10 kind of thing for now. It will, hopefully, improve over time. Error checking is thin/non-existent for now. Things may change. Just writing this I've spotted things I probably should change. I'll add commit comments when I do of course.

