# PoSHue
A couple of PowerShell classes (yes, really) that assist in getting simpler access to Philips Hue Luminaires using the REST API of the Hue Bridge.

Now a listed tool on [Philips' developer site](http://www.developers.meethue.com/tools-and-sdks). Lonely by itself under the PowerShell section!

**Now [available as a module from the PowerShell Gallery](https://www.powershellgallery.com/packages/PoSHue).**

```powershell
Install-Module -Name PoSHue
```

## Why?
I have a few Philips Hue Luminaires (Beyond Lamp, Hue Go (x2) and Bloom) and I wanted a way of controlling them using PowerShell but fiddling with JSON every time I wanted to control them seemed a bit verbose. I've boiled down the basic actions to make it simple to use PowerShell to access the RESTful API on the bridge. Using PowerShell means you can script lighting changes quickly and easily and use Windows' own native task scheduler to run the scripts whenever you like.

## Go on then, how do I use it?
### Pre-requisites
 * [WMF/PowerShell 5.0](https://www.microsoft.com/en-us/download/details.aspx?id=50395) (this went RTM (again) on 24th February 2016) 
 * You need to be on your LAN with the Hue Bridge, obviously.
 * *I provide [`RGBtoXY.ps1`](../master/RGBtoXY.ps1) as a standalone, easy to understand and run script file for the benefit of people looking to get an XY value from an RGB colour. This file is _not_ included in releases or the module when installed from the PowerShell Gallery.* 

---

### Using it
Install the module from the PowerShell Gallery.
```powershell
Install-Module -Name PoSHue # Installs the latest version of the module from the PowerShell Gallery
```

Or you may wish to download the latest release and copy [`PoSHue.ps1`](../master/PoSHue.ps1) and [`PoSHue.psd1`](../master/PoSHue.psd1) to the same folder as your script (or somewhere else if you want!) and `Import-Module` on its location. If you are loading directly from just the `PoSHue.ps1` file, you may also need to `Add-Type -AssembylName System.Drawing` otherwise you will receive a parser error.

####First lines
Assuming you've installed from the PowerShell Gallery, your starting script looks as follows.
```powershell
Import-Module -Name PoSHue
```

---

#### HueBridge Class
Let's start with the `[HueBridge]` class. Use this to get an APIKey/username from your bridge so you can get and set light data with it using the `[HueLight]` class later.
 1. Get the IP address of your Bridge. The `[HueBridge]` class contains a static method (this means you can call it without instantiating the class) called `.FindHueBridge()`.
 2. Run
 
 ```powershell
 PS C:\>[HueBridge]::FindHueBridge()
 ```
 3. Your computer will perform a search. The search is synchronous (means you need to wait for it to complete) and takes about 15-20 seconds to finish. The method finds all UPnP devices described as "Hue" on your LAN (Subnet) and returns those as a list, giving you the IP of your bridge. One might argue this should happen by default, after all, the Hue Bridge IP address may change in a DHCP network. Two reasons why I don't do this automagically: 1. Who says this is the only Hue Bridge in the network? 2. The method call is a blocking action and I've not tried to get PowerShell to do stuff asynchronously with a callback yet. <br/> 
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/findhuebridge-1.gif "FindHueBridge()")
 
 4. Instantiate a `[HueBridge]` class using your discovered (or known) Bridge IP address. Substitue your own bridge's IP address obviously.
 
 ```powershell
 PS C:\>$Bridge = [HueBridge]::New('192.168.1.12')
 ```
 5. Get the properties of the Bridge object.
 
 ```powershell
 PS C:\>$Bridge
 ```
 6. You'll see just the IP address property for now. <br/>
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/bridgeobject.gif "Bridge Object")
 7. Get a new APIKey (username) for the bridge. This is what you use to authenticate with the bridge to get and set information about the lights. The only way to get the key is to press the link button on your bridge and then ask for an APIKey/username.
 8. Press the link button on the bridge then run:
 
 ```powershell
 PS C:\>$Bridge.GetNewAPIKey()
 ```
 9. You should get a string of characters and digits back. Record these for further use (with the `[HueLight]` class).<br/>
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/getapikey.gif "GetNewAPIKey()")<br/>
 *In the preceding demo I used an emulator to demonstrate how to get a key. You would substitute in your own bridge IP!*
 10. Now that you have an APIKey/username stored in your bridge object, go ahead and get a list of the lights on the Bridge using:
 
 ```powershell
 PS C:\>$Bridge.GetLightNames()
 ```
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/bridgegetlightnames.gif "GetLightNames()")
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
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/bridgegetlights.gif "GetAllLights()")<br/>
 You should of course assign the returned `[PSObject]` to a variable so that you can navigate it as you wish.
 15. If you just want to turn all Hue Lights on or off (all lights will become the same state). Use:
  ```powershell
 PS C:\>$Bridge.ToggleAllLights("On")
 PS C:\>$Bridge.ToggleAllLights("Off")
  ```

---

#### HueGroup Class
The HueGroup class allows you to create, edit and delete groups. Although not documented, the HueGroup also allows you to control brightness, hue, saturation and XY values of light groups and rooms in the same way as individual lights.
To get started with the HueGroup class, instantiate it. There are two constructors for the HueGroup class, one requires the name of an existing group. The other does not and is intended for the purposes of managing groups where you do not specifically want to instantiate from an existing group first.

 1. This first example creates a blank group object and is intended for management of groups and finding out what group names there are. First I create a group object and then I recall the group to see its properties. The properties are all set at the default values and you can see the `Group` and `GroupFriendlyName` properties are not set.

 ```powershell
 PS C:\>$Group = [HueGroup]::New('192.168.1.12', '38cbd1cbcac542f9c26ad393739b7')

 PS C:\>$Group
 Group             : 
 GroupFriendlyName : 
 BridgeIP          : 192.168.1.12
 APIKey            : 38cbd1cbcac542f9c26ad393739b7
 JSON              : 
 On                : False
 Brightness        : 0
 Hue               : 0
 Saturation        : 0
 ColourTemperature : 0
 XY                : {y, x}
 ColourMode        : xy
 AlertEffect       : none
 Lights            : 
 GroupClass        : Kitchen
 GroupType         : 
 AnyOn             : False
 AllOn             : False
 ```
 2. This second example instantiates a group object and binds it to the `$Group` variable. Now that we have provided a valid group name, the properties are set.

 ```powershell
 PS C:\>$Group = [HueGroup]::New('Test', '192.168.1.12', '38cbd1cbcac542f9c26ad393739b7')

 PS C:\>$Group
 Group             : 10
 GroupFriendlyName : Test
 BridgeIP          : 192.168.1.12
 APIKey            : 38cbd1cbcac542f9c26ad393739b7
 JSON              : 
 On                : False
 Brightness        : 254
 Hue               : 7688
 Saturation        : 199
 ColourTemperature : 443
 XY                : {y, x}
 ColourMode        : xy
 AlertEffect       : none
 Lights            : {5, 6}
 GroupClass        : Other
 GroupType         : LightGroup
 AnyOn             : False
 AllOn             : False
 ```

#### Get a list of groups:
 **Syntax**
 ```powershell
 [PSObject] GetLightGroups()
 ```
 **Usage**
```powershell
PS C:\> $Group.GetLightGroups()


1  : @{name=Hue Beyond 1; lights=System.Object[]; type=Luminaire; state=; uniqueid=00:37:c7:c8; modelid=HBL001; action=}
2  : @{name=Hue Beyond Down 1; lights=System.Object[]; type=LightSource; state=; uniqueid=00:37:c7:c8-02; action=}
3  : @{name=Hue Beyond Up 1; lights=System.Object[]; type=LightSource; state=; uniqueid=00:37:c7:c8-01; action=}
4  : @{name=Lounge; lights=System.Object[]; type=Room; state=; class=Living room; action=}
5  : @{name=Hall; lights=System.Object[]; type=Room; state=; class=Hallway; action=}
6  : @{name=Office; lights=System.Object[]; type=Room; state=; class=Office; action=}
7  : @{name=Bedroom; lights=System.Object[]; type=Room; state=; class=Bedroom; action=}
8  : @{name=Loft; lights=System.Object[]; type=Room; state=; class=Living room; action=}
9  : @{name=Kitchen; lights=System.Object[]; type=Room; state=; class=Living room; action=}
10 : @{name=Test; lights=System.Object[]; type=LightGroup; state=; recycle=False; action=} ```
```
---
#### Get a single group ID:
This is a hidden method but is documented here for benefit.

 **Syntax**
 ```powershell
 hidden [int] GetLightGroup(string Name)
 ```
 **Usage**
```powershell
PS C:\> $Group.GetLightGroup('Test')
10

```
---

#### Create a group:

**NB: *To obtain a list of light IDs, use the `GetAllLights()` method from the [HueBridge] class.***

There are two overloads for the CreateLightGroup() method. Each creates a different "type" of group. The two types of group are:
 * **LightGroup** - a LightGroup is a group of lights. The lights in the group can be any or all lights, whether they are a member of an existing group or not.
 * **Room** - a Room is a defined area within the home that contains lights. Lights can only belong to a single room at any one time. So, for example, a light cannot be in a group called Bedroom and a group called Kitchen at the same time. To define a Room group type, you must provide a RoomClass. To obtain a list of acceptable RoomClasses, use the following command after importing the module to your session.
 ```powershell
 PS C:\> [system.enum]::GetNames([RoomClass])
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
 ```
After creating the group, the object properties are populated with the newly created group.

 **Syntax**
 ```powershell
[void] CreateLightGroup([string] GroupName, [string[]] LightID) # Create LightGroup
[void] CreateLightGroup([string] GroupName, [RoomClass] RoomClass, [string[]] LightID) # Create Room
 ```
 **Usage**
```powershell
PS C:\> $Group.CreateLightGroup('Test', @(5,6)) # Returns nothing, group is created, $Group is updated.
PS C:\> $Group.CreateLightGroup('Test', 'Bedroom', @(5,6)) # Returns nothing, group is created, $Group is updated.

```
---
#### Delete a group:
 **Syntax**
 ```powershell
 [string] DeleteLightGroup([string] GroupName)
 ```
 **Usage**
```powershell
PS C:\> $Group.DeleteLightGroup('Test')
/groups/10 deleted

```
---

#### Change a group:
To change a group, it must already exist and be instantiated in your variable/object ie. the object must be set to (instantiated against) an existing group already. The purpose of this method is to allow you to both change the name and/or change the lights of an existing group which you have already instantiated.

 **Syntax**
 ```powershell
 [void] EditHueGroup([string] Name, [string[]] LightIDs)
 ```
 **Usage**
```powershell
PS C:\> $Group.EditHueGroup('Test', @(5,6,7)) # Returns nothing, group is updated, $Group is updated.
```
---

#### Turn a group on or off:
There are three overloads for the SwitchHueGroup() method.

 **Syntax**
 ```powershell
 [void] SwitchHueGroup()
 [void] SwitchHueGroup([LightState] State)
 [void] SwitchHueGroup([LightState] State, [bool] Transition)
 ```
 **Usage**
```powershell
PS C:\> $Group.SwitchHueGroup() # Returns nothing, toggles all lights in the group on or off.
PS C:\> $Group.SwitchHueGroup('on') # Returns nothing, toggles all lights in the group on.
PS C:\> $Group.SwitchHueGroup('on', $true) # Returns nothing, toggles all lights in the group on and ready for transition effect (Brightness=1).
```
---

#### Specify the Brightness and XY co-ordinate values of a Group
*I capitulated and included an XY method to take advantage of RGB to XY conversion. The conversion to get from RGB to an XY value in the correct colour Gamut for a specific model is quite involved so I have included more detailed steps for this method in an additional section below. The information there applies to lights and groups equally but if you attempt to set a colour for one light in a group that has a different Gamut to other lights, something will look slightly off/different colour reproduction.*
 
 **Syntax:**
 ```powershell
 [string] SetHueGroup([int] $Brightness, [float] $X, [float] $Y)
 ```
 
 **Usage:**
 ```powershell
 PS C:\>$Group.SetHueGroup(150, 0.4123, 0.1348) # Returns [string] Success
 ```  
---
 
#### Specify the Brightness and/or Colour Temperature
Not all Hue Lights support colour temperature - the class looks for the CT attribute, if it doesn't exist, this method will return an error advising that the light does not hold this setting and it therefore cannot be set.

 **Syntax**
 ```powershell
 [string] SetHueGroup([int] $Brightness, [int] $ColourTemperature)
 ```
 **Usage**
 ```powershell
 PS C:\>$Group.SetHueGroup(150, 380) # Returns [string] Success
 ```
  ---
 
#### Specify the Brightness and/or Hue and/or Saturation
**Syntax** 
```powershell
[string] SetHueGroup([int] $Brightness, [int] $Hue, [int] $Saturation)
```
**Usage**
```powershell
PS C:\>$Group.SetHueGroup(150, 45500, 150) # Returns [string] Success
```
---




#### HueLight Class
The HueLight class allows you to set properties of a light (the interesting stuff!) like Brightness, XY, Hue & Saturation and Colour Temperature. When you instantiate the `[HueLight]` class, you do so by providing the IP Address of your bridge, the APIKey/username and the _name_ of the Hue Light you want to control.
There are obviously some restrictions on what values you can set for the light and these restrictions are imposed using the object's properties. These are limits imposed by the capabilities of the hardware rather than me, I just repeat those limits within the code.
 1. Instantiate the `[HueLight]` class, providing the necessary details. Obviously you can specify these as variables if you like.
 
 ```powershell
 PS C:\>$Light = [HueLight]::New('Hue go 1', '192.168.1.12', '38cbd1cbcac542f9c26ad393739b7')
 ```
 2. Call the object to see its properties. <br/>
 ![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/newlight.gif "Hue Light")
 3. As part of instantiating/constructing the `$Light` object, the `[HueLight]` class gets the existing *state* of the light from the Bridge. It sets values like **On** (whether the light is on or off), **Brightness**, **Hue**, **Saturation** and **Colour Temperature**. When you change these values using the methods described below, the object's properties are also updated and you can use these as you see fit.
 4. Now you have the `$Light` object (which is a Hue Light on your Bridge). Use any of the methods defined in the class to control it. To get a full list, either use IntelliSense or consult the class itself. The most useful methods are described below.

Here's a demo of the entire end-to end process in just four lines.<br/>
![alt-text](http://www.lewisroberts.com/wp-content/uploads/2016/04/HueLight.gif "HueLight class in action.")

---
#### Toggle the light on or off:
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
 
#### Set the state of the light:
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

#### Set the state of the light ready for transition:
I included this to allow use of things like slow transitions from off to on, like implementing your own sunrise.
 **Syntax**
  ```powershell
 [void] SwitchHueLight([LightState] $State, [bool] $Transition)
  ```

 **Usage**
 ```powershell
 PS C:\>$Light.SwitchHueLight("On", $true) # Returns nothing (light switches on to brightness of 1)
 PS C:\>$Light.SwitchHueLight("Off", $true) # Returns nothing (light switches off - same as $Light.SwitchHueLight("Off")
 ```
 ---
 
#### Specify the Brightness and XY co-ordinate values
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
 
#### Specify the Brightness and/or Colour Temperature
Not all Hue Lights support colour temperature - the class looks for the CT attribute, if it doesn't exist, this method will return an error advising that the light does not hold this setting and it therefore cannot be set.

 **Syntax**
 ```powershell
 [string] SetHueLight([int] $Brightness, [int] $ColourTemperature)
 ```
 **Usage**
 ```powershell
 PS C:\>$Light.SetHueLight(150, 380) # Returns [string] Success
 ```
  ---
 
#### Specify the Brightness and/or Hue and/or Saturation
**Syntax** 
```powershell
[string] SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation)
```
**Usage**
```powershell
PS C:\>$Light.SetHueLight(150, 45500, 150) # Returns [string] Success
```
---
  
#### Perform a Breathe action

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
#### Change Brightness and/or XY values with transition
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

#### Change Brightness and/or colour temperature with transition
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
#### Change Brightness and/or Hue and/or Saturation with transition
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
### Retaining current settings
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
### Converting RGB to XY & Brightness
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
Import-Module -Name PoSHue

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
Import-Module -Name PoSHive # Assumes PoSHiuve is installed
Import-Module -Name PoSHue

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

