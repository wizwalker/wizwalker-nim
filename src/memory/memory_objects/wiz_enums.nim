
type 
  PlayerStatus* {.pure.} = enum
    ## The statuses a player can be in
    unknown = 0
    offline = 1
    link_dead = 2
    transition = 3
    online = 4
    ignored = 5
