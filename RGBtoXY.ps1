Function RGBtoXYZ([System.Drawing.Color] $Colour) {
    # Set up a return value [hashtable]
    $ret = @{}
    [float] $r = $Colour.R/255;
    [float] $g = $Colour.G/255;
    [float] $b = $Colour.B/255;

    # Gamma correction
    [float] $red = if ($r -gt [float]0.04045) { [Math]::Pow(($r + [float]0.055) / ([float]1.0 + [float]0.055), [float]2.4) } Else { ($r / [float]12.92) }
    [float] $green = if ($g -gt [float]0.04045) { [Math]::Pow(($g + [float]0.055) / ([float]1.0 + [float]0.055), [float]2.4) } Else { ($g / [float]12.92) }
    [float] $blue = if ($b -gt [float]0.04045) { [Math]::Pow(($b + [float]0.055) / ([float]1.0 + [float]0.055), [float]2.4) } Else{ ($b / [float]12.92) }

    #<#
    # Convert the RGB values to XYZ using the Wide RGB D65 conversion formula
    [float] $x = $red * [float]0.664511 + $green * [float]0.154324 + $blue * [float]0.162028;
    [float] $y = $red * [float]0.283881 + $green * [float]0.668433 + $blue * [float]0.047685;
    [float] $z = $red * [float]0.000088 + $green * [float]0.072310 + $blue * [float]0.986039;
    #>

    [float] $ret.x = $x / ($x + $y + $z)
    [float] $ret.y = $y / ($x + $y + $z)
    [float] $ret.z = $z / ($x + $y + $z)

    Return $ret
}

Function GamutTriangles($Gamut) {

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
    }

    Return $GamutTriangles."$Gamut"
}

Function crossProduct($p1, $p2) {
        return [float]($p1.x * $p2.y - $p1.y * $p2.x)
}

Function isPointInTriangle($p, [psobject]$triangle) {
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

    $s = (crossProduct $q $v2) / (crossProduct $v1 $v2)
    $t = (crossProduct $v1 $q) / (crossProduct $v1 $v2)
    return ($s -ge [float]0.0) -and ($t -ge [float]0.0) -and ($s + $t -le [float]1.0)
}

Function closestPointOnLine($a, $b, $p) {
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

Function distance($p1, $p2) {
    [float] $dx = $p1.x - $p2.x
    [float] $dy = $p1.y - $p2.y
    [float] $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
    return $dist
}

Function xyForModel($xy, $Gamut) {
    $triangle = GamutTriangles $Gamut
    If (isPointInTriangle $xy -triangle $triangle) {
        return @{
            x = $xy.x
            y = $xy.y
        }
    }
    $pAB = closestPointOnLine $triangle.Red $triangle.Green $xy
    $pAC = closestPointOnLine $triangle.Blue $triangle.Red $xy
    $pBC = closestPointOnLine $triangle.Green $triangle.Blue $xy
    [float] $dAB = distance $xy $pAB
    [float] $dAC = distance $xy $pAC
    [float] $dBC = distance $xy $pBC
    [float] $lowest = $dAB

    $closestPoint = $pAB
    If($dAC -lt $lowest) {
        $lowest = $dAC
        $closestPoint = $pAC
    }
    if($dBC -lt $lowest) {
        $lowest = $dBC
        $closestPoint = $pBC
    }
    return $closestPoint;
}

Function xybForModel($ConvertedXYZ, $TargetGamut ) {
    $xy = xyForModel -xy $ConvertedXYZ -Gamut $TargetGamut
    $xyb = @{
        x = $xy.x
        y = $xy.y
        b = [int]($ConvertedXYZ.z*255)
    }
    Return $xyb
}
$ColourTemps = @{
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

$XYZ = RGBtoXYZ -Colour $ColourTemps.t17 # Convert the colour with gamma correction

[psobject]$GamutC = GamutTriangles('GamutC') # Get the gamut of the target light

isPointInTriangle -p $XYZ -triangle $GamutC # Tells us if the light can support the colour without alteration

xybForModel $XYZ 'GamutC'

#Write-Host "."

#xyForModel $XYZ 'GamutC'

