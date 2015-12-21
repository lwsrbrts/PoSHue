# PoSHue
A couple of PowerShell classes (no, really) that assist in getting simpler access to Philips Hue Luminaires using the REST API of the Hue Bridge.

## Why?
I have a few Philips Hue Luminaires (Beyond Lamp, Hue Go and Bloom) and I wanted a way of controlling them using PowerShell but fiddling with JSON every time I wanted to control them seemed a bit verbose. I've boiled down the basic actions to make it simple to use PowerShell to access the RESTful API on the bridge.

## Go on then, how do I use it?
### Pre-requisites
 * WMF/PowerShell 5.0 (this went RTM on 16th December 2015)
 * You only need the PoSHue.ps1 file. It contains the classes you'll use.
 * You need to be on your LAN with the Hue Bridge, obviously.

### Using it
I haven't tried this myself but one of the limitations of PowerShell 5 classes are that you must use the same script context. It can't be called as a module so to speak. I'm sure they're working on this.
#### HueBridge Class
Let's start with the ```[HueBridge]``` class. Use this to get an APIKey/username from your bridge so you can get and set light data with it using the ```[HueLight]``` class later.
1. Get the IP address of your Bridge. Your router might be a good place to look.
2. At the bottom of the PoSHue file, instantiate a HueBridge class. Substitue your own bridge's IP address obviously. ```$Bridge = [HueBridge]::New('192.168.1.12')```
3. Get the properties of the Bridge object. ```$Bridge```
4. You'll see just the IP address property for now.
5. Get a new APIKey (username) for the bridge. This is what you use to authenticate with the bridge when you're asking for information. The only way to get this is to press the link button on your bridge.
6. Press the link button on the bridge then call the ```$Bridge.GetNewAPIKey()``` method.
7. You should get a string of digits back. Record these for further use. Pressing the link button on the Bridge might get tedious! You're automating, remember. :)
8. Now that you have an APIKey/username stored in your bridge object, go ahead and get a list of the lights on the Bridge using the ```$Bridge.GetLightNames()``` method.
9. You should see a list (an array) of lights registered to the bridge. The Bridge uses numbers to refer to the lights - we humans aren't great at associating numbers with objects so I use names. The ```[HueLight]``` class also uses names instead of numbers.
10. If you call ```$Bridge``` again by itself, you'll see the APIKey property. Remember, save this somewhere.
11. If you already have an APIKey/username, you can instantiate the ```[HueBridge]``` class with that in order to use the ```.GetLightNames()``` method to get the names of the lights on the bridge. Something like ```$Bridge = [HueBridge]::New('192.168.1.12', '23343462grg456brergd56')```

#### HueLight Class
The HueLight class allows you to set properties of a light (the interesting stuff!) like Brightness, Hue & Saturation and Colour Temperature. When you instantiate the ```[HueLight]``` class, you do so by providing the IP Address of your bridge, the APIKey/username and the name of the Hue Light you want to control.
1. Instantiate the ```[HueLight]``` class, providing the necessary details. Obviously you can specify these as variables if you like. ```$Lamp = [HueLight]::New('Hue go 1', '192.168.1.12', '23343462grg456brergd56')```
2. Call the object to see its properties. ```$Light```
3. As part of instantiating/constructing the ```$Light``` object, the ```[HueLight]``` class gets the existing *state* of the light from the Bridge. It sets values like **On** (whether the light is on or off), **Brightness**, **Hue**, **Saturation** and **Colour Temperature**.
4. Now you have the ```$Light``` object (which is a Hue Light on your Bridge). Use any of the methods defined to control it.
 * ```.SwitchHueLight()``` - toggle the light on or off.
 * ```.SwitchHueLight([string] State)``` - specify on or off.
 * ```.SetHueLight([int] $Brightness, [int] $ColourTemperature)``` - specify the Brightness and/or Colour Temperature (not all Hue Lights support this!)
 * ```.SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation)``` - specify the Brightness and/or Hue and/or Saturation.

To retain the same settings for one or more property such as Brightness, just use the existing property of the object and essentially, set it again!

For example: ```$Light.SetHueLight(50, $Light.ColourTemperature)``` would retain the same colour temperature as already set in the object but set the brightness to 50. If you then wanted to change the Colour Temperature but retain the Brightness as 50 you would do: ```$Light.SetHueLight($Light.Brightness, 370)```  

# Any questions?
No? Good.
Seriously though, this is a starter for 10 kind of thing for now. Error checking is thin/non-existent for now. Things may change. Just writing this I've spotted things I probably should change. I'll add commit comments when I do of course.