# PoSHue
A couple of PowerShell classes (no, really) that assist in getting simpler access to Philips Hue Luminaires using the REST API of the Hue Bridge.

## Why?
I have a few Philips Hue Luminaires (Beyond Lamp, Hue Go and Bloom) and I wanted a way of controlling them using PowerShell but fiddling with JSON every time I wanted to control them seemed a bit verbose. I've boiled down the basic actions to make it simple to use PowerShell to access the RESTful API on the bridge.

## Go on then, how do I use it?
### Pre-requisites
 * WMF/PowerShell 5.0 (this went RTM on 16th December 2015)
 * You only need the PoSHue.ps1 file. It contains the classes you'll use.
 * You need to be on your LAN with the Hue Bridge, obviously.

---

### Using it
Copy the PoSHue.ps1 file to the same folder as your script (or somewhere else if you want!) and use Import-Module on its location. See Using-PoSHue.ps1 for an example of doing that.

----

#### HueBridge Class
Let's start with the ```[HueBridge]``` class. Use this to get an APIKey/username from your bridge so you can get and set light data with it using the ```[HueLight]``` class later.
 1. Get the IP address of your Bridge. The ```[HueBridge]``` class contains a static method (this means you can call it without instantiating the class) called ```.FindHueBridge()```.
 2. Run
 
 ```powershell
 PS:>[HueBridge]::FindHueBridge()
 ```
 3. Your computer will perform a search. The search is synchronous (means you need to wait for it to complete) and takes about 15-20 seconds to finish. The method finds all UPnP devices described as "Hue" on your LAN (Subnet) and returns those as a list, giving you the IP of your bridge. One might argue this should happen by default, after all, the Hue Bridge IP address may change in a DHCP network. Two reasons why I don't do this automagically: 1. Who says this is the only Hue Bridge in the network? 2. The method call is a blocking action and I've not tried to get PowerShell to do stuff asynchronously with a callback yet.
 4. Instantiate a ```[HueBridge]``` class using your discovered (or known) Bridge IP address. Substitue your own bridge's IP address obviously.
 
 ```powershell
 $Bridge = [HueBridge]::New('192.168.1.12')
 ```
 5. Get the properties of the Bridge object.
 
 ```powershell
 $Bridge
 ```
 6. You'll see just the IP address property for now.
 7. Get a new APIKey (username) for the bridge. This is what you use to authenticate with the bridge to get and set information about the lights. The only way to get the key is to press the link button on your bridge and then ask for an APIKey/username.
 8. Press the link button on the bridge then run:
 
 ```powershell
 $Bridge.GetNewAPIKey()
 ```
 9. You should get a string of digits back. Record these for further use (with the ```[HueLight]``` class). Pressing the link button on the Bridge might get tedious! You're automating, remember. :)
 10. Now that you have an APIKey/username stored in your bridge object, go ahead and get a list of the lights on the Bridge using:
 
 ```powershell
 $Bridge.GetLightNames()
 ```
 11. You should see a list (an array) of lights registered to the bridge. The Bridge uses numbers to refer to the lights - we humans aren't great at associating numbers with objects so I use the names of the lights. The ```[HueLight]``` class also uses names instead of numbers.
 12. If you call ```$Bridge``` again by itself, you'll see the ```APIKey``` property there too. Remember, save this somewhere.
 13. If you already have an APIKey/username, you can instantiate the ```[HueBridge]``` class with that in order to use the ```.GetLightNames()``` method to get the names of the lights on the bridge. Something like: 
 
 ```powershell
 $Bridge = [HueBridge]::New('192.168.1.12', '23343462grg456brergd56')
 ```
 14. If you are struggling with something or want to get an unabashed set of data (as a PowerShell ```[PSObject]```) about your lights from the bridge, use:
 
 ```powershell
 $Bridge.GetAllLights()
 ```

---

#### HueLight Class
The HueLight class allows you to set properties of a light (the interesting stuff!) like Brightness, Hue & Saturation and Colour Temperature. When you instantiate the ```[HueLight]``` class, you do so by providing the IP Address of your bridge, the APIKey/username and the name of the Hue Light you want to control.
There are obviously some restrictions on what you can set and these restrictions are imposed using the object's properties. These are limits imposed by the capabilities of the hardware. You could obviously change the ValidateRange but the lights won't accept a value outside these anyway so you needn't bother.
 1. Instantiate the ```[HueLight]``` class, providing the necessary details. Obviously you can specify these as variables if you like.
 
 ```powershell
 $Lamp = [HueLight]::New('Hue go 1', '192.168.1.12', '23343462grg456brergd56')
 ```
 2. Call the object to see its properties.
 
 ```powershell
 PS:>$Light
 
 Light             : 4
 BridgeIP          : 192.168.1.12
 APIKey            : 38cbd1cbcac542f9c26ad393739b7
 JSON              : 
 On                : True
 Brightness        : 106
 Hue               : 8590
 Saturation        : 121
 ColourTemperature : 343
 
 ```
 3. As part of instantiating/constructing the ```$Light``` object, the ```[HueLight]``` class gets the existing *state* of the light from the Bridge. It sets values like **On** (whether the light is on or off), **Brightness**, **Hue**, **Saturation** and **Colour Temperature**. When you change these values using the methods described below, the object's properties are also updated and you can use these as you see fit.
 4. Now you have the ```$Light``` object (which is a Hue Light on your Bridge). Use any of the methods defined to control it. To get a full list, either use IntelliSense or consult the class itself. The most useful methods are described below:
  * Toggle the light on or off:
 
 ```powershell
 $Light.SwitchHueLight()
 ```
  * Set the state of the light:
 
 ```powershell
 $Light.SwitchHueLight("On")
 $Light.SwitchHueLight("Off")
 ```
  * Specify the Brightness and/or Colour Temperature (not all Hue Lights support colour temperature)
 
 ```powershell
 $Light.SetHueLight([int] $Brightness, [int] $ColourTemperature)
 ``` 
  * Specify the Brightness and/or Hue and/or Saturation.
 
  ```powershell
  $Light.SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation)
  ```

To retain the same settings for one or more property such as Brightness, just use the existing property of the object and essentially, set it again!

For example, the following command would retain the same colour temperature as already set in the object but set the brightness to 50:

```powershell
$Light.SetHueLight(50, $Light.ColourTemperature)
```
If you then wanted to change the Colour Temperature to 370 but retain the Brightness as 50 you would do: 

```powershell
$Light.SetHueLight($Light.Brightness, 370)
```  

# Any questions?
No? Good.
Seriously though, this is a starter for 10 kind of thing for now, it will, hopefully, improve over time. Error checking is thin/non-existent for now. Things may change. Just writing this I've spotted things I probably should change. I'll add commit comments when I do of course.