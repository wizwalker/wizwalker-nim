
type 
  ObjectType* {.pure.} = enum
    ## Types of objects
    undefined = 0
    player = 1
    npc = 2
    prop = 3
    obj = 4
    house = 5
    key = 6
    old_key = 7
    deed = 8
    mail = 9
    equip_head = 10
    equip_chest = 11
    equip_legs = 12
    equip_hands = 13
    equip_finger = 14
    equip_feet = 15
    equip_ear = 16
    recipe = 17
    building_block = 18
    building_block_solid = 19
    golf = 20
    door = 21
    pet = 22
    fabric = 23
    window = 24
    roof = 25
    horse = 26
    structure = 27
    housing_texture = 28
    plant = 29

  PlayerStatus* {.pure.} = enum
    ## The statuses a player can be in
    unknown = 0
    offline = 1
    link_dead = 2
    transition = 3
    online = 4
    ignored = 5
