Measured values:
----------------
```
HSSTRT : $01A (PAL), $01A (NTSC)
HSSTOP : $03B,$029 (PAL), $03B, $02B (NTSC)
HBSTRT : $00E (PAL), $00D (NTSC)
HBSTOP : $05C (PAL), $05C (NTSC)
```
PAL interlaced:
---------------
```
  8 x STREQU \
 18 x STRVBL  | 312 lines
286 x STRHOR /
  9 x STREQU \
 17 x STRVBL  | 313 lines
287 x STRHOR /
```
PAL non-interlaced:
-------------------
```
  9 x STREQU \
 17 x STRVBL  | 313 lines
287 x STRHOR /
```
NTSC interlaced:
----------------
```
 10 x STREQU \
 11 x STRVBL  | 262 lines with 131 x STRLONG
241 x STRHOR /
 10 x STREQU \
 11 x STRVBL  | 263 lines with 131/132 x STRLONG
242 x STRHOR /
```
NTSC non-interlaced:
--------------------
```
 10 x STREQU \
 11 x STRVBL  | 263 lines with with 131/132 x STRLONG
242 x STRHOR /
```
