breed [adults adult]
breed [children child]

globals [
  generation-counter         ; keeps track of the generation number
  initial-population         ; number of foreign speakers to begin with
  full-population-size       ; total number of people in community if all houses have 2 parents
  proficiency-weight         ; weight of avg parent proficiency in pass on calculation
  env-weight                 ; weight of avg parent proficiency in pass on calculation
  radius-weight              ; weight of avg parent proficiency in pass on calculation
  fluent-cutoff              ; value above which someone is fluent
  influx-prob                ; 1 - probability that incoming person is immgrating
  env-factor-list            ; list of environmental factors for each quadrant
  dispersal-factor           ; percentage of adults to randomly disperse at each time steps
  neighbourhood-size         ; size of square which people move within
]

adults-own [
  proficiency                ; profiency in foreign language
  im-gen                     ; generation of immigration
]

children-own [
  proficiency                ; profiency in foreign language
  im-gen                     ; generation of immigration
]

patches-own [
 net-proficiency             ; sum of profiency in the patch (have to divide by 2 to normalize)
 env-factor                  ; environmental factor
 radius-factor               ; sum of profiency in neighbouring patches (have to divide by 9 to normalize)
]

; setup the model
to setup
  clear-all
  set proficiency-weight 0.7
  set radius-weight 0.1
  set env-weight 1 - ( proficiency-weight + radius-weight )

  set fluent-cutoff 0.7
  set influx-prob 0.9
  set env-factor-list (list 0  ( 1 / 3 )  ( 2 / 3 )  1 )
  set dispersal-factor 0.05


  set generation-counter 1     ; Start at generation 1
  set initial-population 2 * 200 ; initial number of immigrants
  set full-population-size 2 * ( ( 2 * max-pxcor ) + 1 ) * ( ( 2 * max-pycor ) + 1 )

  set neighbourhood-size 3

  ; variables to define number of foreign speakers left to initialize
  let foreign-to-sprout initial-population

  ; put people in each patch
  ask patches [

    ; choose to either initialize a fluent speaker or a local
    ifelse foreign-to-sprout > 0 [
      ; sprout two fluent speakers
      sprout 2 [
        set breed adults
        set proficiency 1
        set im-gen 1
        recolor-person
      ]
     ; reduce number of fluent speakers left to sprout
     set foreign-to-sprout (foreign-to-sprout - 2)
    ][
      ; sprout two locals
      sprout 2 [
          set breed adults
          set proficiency 0
          set im-gen -1
          recolor-person
      ]
      set net-proficiency 0
    ]
    ; update net-proficiency, radius factor, house color
    calculate-net-proficiency
    calculate-radius-factor

    ; set environmental factor based on position
    set-env-factor
    recolor-household-env

  ]

  report-avg-proficiency
  report-num-fluent
  reset-ticks
end

to set-env-factor
  (ifelse
    pxcor < 0 and pycor <  0[
      set  env-factor item 0 env-factor-list
    ]
    pxcor >= 0 and pycor <  0[
      set env-factor item 1 env-factor-list
    ]
    pxcor >= 0 and pycor >=  0[
      set env-factor item 2 env-factor-list
    ]
  ; else
    [
      set env-factor item 3 env-factor-list
  ])
end

; update person color based on proficiency
to recolor-person
  set color 129.9 - 4.5 * proficiency
end
; update patch color based on net proficiency
to recolor-household-proficiency
    set pcolor 139 - 2 * net-proficiency
end

; update patch color based on net proficiency
to recolor-household-env
    set pcolor 59 - 2 * env-factor
end

; update patch net proficiency
to calculate-net-proficiency
  let new-net-proficiency 0
  ask adults-here [
    set new-net-proficiency new-net-proficiency + proficiency
  ]
  set net-proficiency new-net-proficiency
end

; update patch radius factor
to calculate-radius-factor
  let new-radius-factor 0
  ask neighbors [
            set new-radius-factor new-radius-factor + net-proficiency
        ]
  set radius-factor new-radius-factor / ( 8 * 2 )
end

; randomly swap the correct number of adults on the grid according to the global variable dispersal-factor
to disperse-adults
  let n-to-disperse round ( dispersal-factor * count adults )
  while [ n-to-disperse > 0 ] [
    rand-swap
    set n-to-disperse n-to-disperse - 1
  ]
end
; randomly swap two adults on the grid
to rand-swap
  let adult-list [self] of adults
  let adult-1 item 0 adult-list
  let adult-1-x [xcor] of adult-1
  let adult-1-y [ycor] of adult-1

  let adult-2 item 1 adult-list
  let adult-2-x [xcor] of adult-2
  let adult-2-y [ycor] of adult-2

  ask adult-1 [ setxy adult-2-x adult-2-y ]
  ask adult-2 [ setxy adult-1-x adult-1-y ]
end

; update environmental factors
to update-env-factor
  let quad-1 ( mean [net-proficiency] of patches with [pxcor < 0 and pycor <  0] ) / ( full-population-size / 4 )

  let quad-2 ( mean [net-proficiency] of patches with [ pxcor >= 0 and pycor <  0] ) / ( full-population-size / 4 )
  set quad-2 quad-2 + ( random-float 1 ) / 10
  if quad-2 > 1 [ set quad-2 1 ]

  let quad-3 ( mean [net-proficiency] of patches with [  pxcor >= 0 and pycor >=  0] ) / ( full-population-size / 4 )
  set quad-3 quad-3 + ( random-float 1 ) / 6
  if quad-3 > 1 [ set quad-3 1 ]

  let quad-4 ( mean [net-proficiency] of patches with [  pxcor < 0 and pycor >=  0] ) / ( full-population-size / 4 )
  set quad-4 quad-4 + ( random-float 1 ) / 3
  if quad-4 > 1 [ set quad-4 1 ]

  set env-factor-list (list quad-1 quad-2 quad-3 quad-4 )
end

; go defines what happens at each step of the simulation
to go
  create-next-generation
  report-avg-proficiency
  report-num-fluent
  tick ; advance the simulation by one time step
end

; create the next generation of households
to create-next-generation
;  birth-children-in-grid  -8 -8 8 8
;  shuffle-children-in-grid  -8 -8 8 8
  loop-over-neighbourhoods
  kill-adults
  grow-children
  disperse-adults
  update-patch-data


  ; create a list of children
  ; in each patch, spawn new children:
  ;    # of kids is normal dist (1.5, 1.5)
  ;    kid profiency = 0.6 * ( p1 + p2 ) / 2 + 0.2 * env + 0.2 * rad
  ; sprout adults based child data
  ; delete children
  ; re calculate patch data

end

to update-patch-data
  ask patches [
    calculate-net-proficiency
  ]

  ask patches [
    calculate-radius-factor
  ]

  update-env-factor
  ask patches [
    set-env-factor
    recolor-household-env
  ]

end

to birth-children
  let total-sprouted 0

  ask patches [
    let num-children round ( random-normal 1.9 1.5 )

    set total-sprouted total-sprouted + num-children

    let num-parents count adults-on self
    let avg-proficiency ( net-proficiency / num-parents )

    let next-im-gen max [im-gen] of adults-on self
    set next-im-gen next-im-gen + 1

    repeat num-children [
      sprout 1 [
        set breed children
        set proficiency ( ( proficiency-weight * avg-proficiency ) + ( env-weight * env-factor ) + ( radius-weight * radius-factor ) )
        set im-gen next-im-gen
        recolor-person
      ]

    ]

  ]

  ; have people move in if not enough babies are made
  ; assumption is people move in with 0 proficiency
  if total-sprouted < full-population-size [
;    print "yes"
    create-turtles ( full-population-size - total-sprouted ) [
      set breed children
      let is-immigrant random-float 1
      ifelse is-immigrant >= influx-prob [
        set proficiency 1
        set im-gen 1
      ] [
        set proficiency 0
        set im-gen -1
      ]


      recolor-person
    ]
  ]


;  print total-sprouted

end

; generates min and max coords for neighbourhoods
; put functions within loop to execute at each neighbourhood
to loop-over-neighbourhoods
  let min-x min-pxcor
  let min-y min-pycor
  let max-x min-x + neighbourhood-size - 1
  let max-y min-y + neighbourhood-size - 1

  while [min-y <= max-pycor] [
    while [min-x <= max-pxcor] [

      ; LOOP BLOCK
      ; COORDS : min-x, min-y, max-x, max-y
      birth-children-in-grid min-x min-y max-x max-y
      shuffle-children-in-grid min-x min-y max-x max-y
;
;      print ( word "MIN X: " min-x " MIN Y: " min-y )
;      print ( word "MAX X: " max-x " MAX Y: "max-y )

      set min-x min-x + neighbourhood-size
      set max-x max-x + neighbourhood-size
      if max-x > max-pxcor [ set max-x max-pxcor ]
     ]
    set min-x min-pxcor
    set max-x min-x + neighbourhood-size - 1

    set min-y min-y + neighbourhood-size
    set max-y max-y + neighbourhood-size
    if max-y > max-pxcor [ set max-y max-pxcor ]
  ]


end

; birth children within grid (inclusive on endpoints)
to birth-children-in-grid [min-x min-y max-x max-y]
  let total-sprouted 0

  ask patches with [pxcor >= min-x and pycor >= min-y and pxcor <= max-x and pycor <= max-y][
    let num-children round ( random-normal 1.9 1.5 )

    set total-sprouted total-sprouted + num-children

    let num-parents count adults-on self
    let avg-proficiency ( net-proficiency / num-parents )

    let next-im-gen max [im-gen] of adults-on self
    set next-im-gen next-im-gen + 1

    repeat num-children [
      sprout 1 [
        set breed children
        set proficiency ( ( proficiency-weight * avg-proficiency ) + ( env-weight * env-factor ) + ( radius-weight * radius-factor ) )
        set im-gen next-im-gen
        recolor-person
      ]

    ]

  ]

  ; have people move in if not enough babies are made
  ; assumption is people move in with 0 proficiency
  let full-grid-population ((max-x - min-x) + 1) * ((max-y - min-y) + 1) * 2
  if total-sprouted < full-grid-population [
;    print "yes"
    create-turtles ( full-grid-population - total-sprouted ) [
      set breed children
      set xcor ( min-x + max-x ) / 2
      set ycor ( min-y + max-y ) / 2
      let is-immigrant random-float 1
      ifelse is-immigrant >= influx-prob [
        set proficiency 1
        set im-gen 1
      ] [
        set proficiency 0
        set im-gen -1
      ]


      recolor-person
    ]
  ]


;  print total-sprouted

end



; shuffle children within grid (inclusive on endpoints)
to shuffle-children-in-grid [min-x min-y max-x max-y]
  let num-shuffled 0

  let spawn-x min-x
  let spawn-y min-y

  ask children with [xcor >= min-x and ycor >= min-y and xcor <= max-x and ycor <= max-y][
    ; remove excess children
    if spawn-y > max-y [
      die
    ]

;    print spawn-x
;    print spawn-y
;    print "\n"
    set xcor spawn-x
    set ycor spawn-y

    set num-shuffled num-shuffled + 1

    ; add two children to each patch
    if num-shuffled mod 2 = 0 and num-shuffled != 0 [
       set spawn-x spawn-x + 1
      ; if the edge of the board is reached, go to next row
      if spawn-x > max-x [
        set spawn-x min-x
        set spawn-y spawn-y + 1
      ]
    ]

  ]

end

to shuffle-children

  let num-shuffled 0

  let spawn-x min-pxcor
  let spawn-y min-pycor

  ask children [
    ; remove excess children
    if spawn-y > max-pycor [
      die
    ]

;    print spawn-x
;    print spawn-y
;    print "\n"
    set xcor spawn-x
    set ycor spawn-y

    set num-shuffled num-shuffled + 1

    ; add two children to each patch
    if num-shuffled mod 2 = 0 and num-shuffled != 0 [
       set spawn-x spawn-x + 1
      ; if the edge of the board is reached, go to next row
      if spawn-x > max-pxcor [
        set spawn-x min-pxcor
        set spawn-y spawn-y + 1
      ]
    ]







  ]

end



to kill-adults
  ask adults [ die ]
end

to grow-children
  ask children [
    set breed adults
  ]
end


to report-avg-proficiency
  print (word "Average Proficiency: " mean [proficiency] of adults)
end

to report-num-fluent
  print (word "Number of Fluent Adults: " count adults with [ proficiency > fluent-cutoff ])
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
832
633
-1
-1
36.12
1
10
1
1
1
0
0
0
1
-8
8
-8
8
0
0
1
ticks
30.0

BUTTON
111
204
177
237
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
113
91
177
124
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
860
14
1133
172
Average Proficiency of Adults over Time
Generations
Avg Proficiency
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [proficiency] of adults"

PLOT
859
189
1136
339
Number of Fluent Speakers over Time
NIL
NIL
0.0
10.0
0.0
578.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count adults with [proficiency > fluent-cutoff]"

BUTTON
114
146
176
179
go (10)
repeat 10 [go]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
