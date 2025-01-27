import std/[os, math, times, strutils, random]
import hacktypes, entities, generator
import illwill 
#--------------------------------\\--------------------------------#

const
    windowSize = 9
    enemyAmount = 8

var 
    tb = newTerminalBuffer(terminalWidth(), terminalHeight())
    running = true
    worldOriginal = loadWorldFile "shop.txt"
    currentWorld = worldOriginal
    world = worldOriginal
    player = Player(name: "player", species: '@', att: 3, def: 3, acc: 10, hp: 10, mp: 10)
    lastAction: string
    camPos: tuple[x,y:int]
    entitySeq: seq[Entity]
    menu, level, turns = 0
    time = cpuTime()
    deadEntities: seq[int]
    goreSeq: seq[tuple[x,y,z:int]]
    worldArr: array[16, World]


proc displayTitleScreen() =
  var n: int
  tb.setForegroundColor(fgYellow)
  var llen: int
  for l in "title.txt".linesInFile:
    tb.write(0,n,l)
    inc n
    llen = l.len
  tb.drawRect(0,0,llen,7)
  n += 1
  for (color, isBright) in [(fgBlack, false),(fgBlack, true),(fgRed, false)]:
    tb.setForegroundColor(color, isBright)
    var nn = n
    for l in "splash.txt".linesInFile:
      tb.write(0,nn,l)
      inc nn
    tb.display()
    sleep(0500)
  sleep(2000)


worldArr[0] = worldOriginal
for i in 1..15:  worldArr[i] = generateWorld() 
player.inventory[0] = Items[1]
player.inventory[1] = Items[2]
player.spells[0] = "(D)ig"

proc placeExit() =
  let z = level
  let (x,y) = chooseSpawn currentWorld
  worldArr[z][y][x] = '>'

proc placeEntities() =
    entitySeq = @[]
    player.pos = chooseSpawn(currentWorld)
    player.ppos = player.pos
    entitySeq.add(player)

    if level != 0:
        placeExit()
        for i in 0..<enemyAmount:
            var temp = Enemies[0]
            deepCopy(temp, Enemies[0])
            temp.pos = chooseSpawn(currentWorld)
            temp.ppos = temp.pos
            temp.path = temp.pos
            entitySeq.add(temp)

placeEntities()

#--------------------------------\\--------------------------------#

proc normalize(x: float|int): int = 
    if x < 0:
        return -1
    elif x > 0:
        return 1
    else:
        return 0

proc distance(e: Entity): float =
    result = sqrt(float((e.pos.x - player.pos.x)^2 + (e.pos.y - player.pos.y)^2))
#--------------------------------\\--------------------------------#

proc drawInitialTerminal() = # Thanks Goat
    tb.setForegroundColor(fgYellow)
    var n = 0
    for line in "ui.txt".linesInFile:
    # This makes sure $hp, $mp and $lv don't literally show up in the UI.
        tb.write(0, n, line.multiReplace({"$hp": "  ", "$mp": "  ", "$lv": "   ", "$act": "   "}))
        inc n

proc clearMenu() =
    for y in 5..11:
        for x in 11..23:
            tb.write(x, y, " ")

proc drawToTerminal() = 
    var n =0
    for line in "ui.txt".linesInFile:
      # The empty space created earlier gets filled.
      # But we are still passing manual x coordinates to do that...
      # which isn't ideal.
        if line.contains("$hp"):
            tb.setForegroundColor(fgRed)
            tb.write(11,n,line[15..21].replace("$hp",$player.hp & " "))
        if line.contains("$mp"):
            tb.setForegroundColor(fgCyan)
            tb.write(18,n,line[23..28].replace("$mp",$player.mp & " "))
        if line.contains("$lv"):
            tb.setForegroundColor(fgYellow)
            tb.write(1,n,"Level:",fgMagenta, $level)
        if line.contains("$act"):
            tb.setForegroundColor(fgYellow)
            tb.write(1,n,lastAction)
        inc n
    for tY in 3..windowSize+2:
        for tX in 1..windowSize:
            let
                wY = camPos.y+tY-3
                wX = camPos.x+tX-1
                tile = world[wY][wX]
            var rtile:string # Replacement char
            case tile
            of 'S':
                tb.setForegroundColor(fgRed, true)
            of '@':
              if player.pos == (wX, wY):
                if player.hp > 0:
                    tb.setForegroundColor(fgYellow, true)
                else:
                    tb.setForegroundColor(fgBlue, bright = true)
              else:
                  tb.setForegroundColor(fgMagenta, true)
            of '>':
                tb.setForegroundColor(fgGreen, bright = true)
            else:
                tb.setForegroundColor(fgBlack, bright = true)
                if (wX,wY,level) in goreSeq:
                  rtile = "•"
                  tb.setForegroundColor(fgRed)
            if rtile != "": tb.write(tX, tY, $rtile)
            else: tb.write(tX, tY, $tile)
            tb.write(0, 28, "TIme: " & $time)
            tb.write(0, 29, "Turn: " & $turns)
            tb.resetAttributes()
    clearMenu()
    case menu
        of 0:
            tb.write(14, 5, "-MENU-")
            tb.write(11, 7, "•(I)nventory")
            tb.write(11, 8, "•(S)pells")
        of 1:
            tb.write(12, 5, "-INVENTORY-")
            tb.write(11, 6, "W: " & player.inventory[0].name)
            tb.write(11, 7, "A: " & player.inventory[1].name)
        of 2:
            tb.write(13, 5, "-SPELLS-")
            for i in 0..<4:
                tb.write(11, 7+i, "•" & player.spells[i])
        of 3:
            tb.write(14, 5, "-DIG-")
            tb.write(11, 6, "Walk into #s")
            tb.write(11, 7, "to dig them.")

        else:
            discard
    tb.display()

    sleep(50)

proc changeLevel(restart: bool = false) =
  # Changes the level. Restarts the level if used as
  # changeLevel(true) or changeLevel(restart = true)
    if restart or level == worldArr.len-1:
        currentWorld = worldOriginal
        level = 0
    else:
        inc level
        currentWorld = worldArr[level]
    placeEntities()

proc getInput() = 
    var key = getKey()
    player.ppos = player.pos
    case key
        of Key.Up:
            player.pos.y -= 1
        of Key.Down:
            player.pos.y += 1
        of Key.Left:
            player.pos.x -= 1
        of Key.Right:
            player.pos.x += 1
        of Key.Plus:
          if level < worldArr.len-1:
            level += 1
            currentWorld = worldArr[level]
        of Key.Minus:
          if level > 0:
            level -= 1
            currentWorld = worldArr[level]
        of Key.Backspace:
            menu = 0
        of Key.R:
            changeLevel(restart = true)
            lastAction = "You return home.    "
        of Key.I:
            if menu == 0:
                menu = 1
        of Key.S:
            if menu == 0:
                menu = 2
        of Key.D:
            if menu == 2:
                menu = 3
        of Key.Q:
            running = false
        else:
            discard
    player.pos.x = clamp(player.pos.x, 0, MapSize - 1)
    player.pos.y = clamp(player.pos.y, 0, MapSize - 1)

proc reset() =
    world = worldArr[level]

proc pathing(e: Entity) =
    if distance(e) < 5 and player.hp > 0:
        e.path = player.pos
    if e.pos != e.path:
        if rand(5) == 0:
            let
                xd = normalize(e.path.x - e.pos.x)
                yd = normalize(e.path.y - e.pos.y)
            if rand(2) == 0:
                e.pos.x += xd
            if rand(2) == 0:
                e.pos.y += yd
    else:
        e.path = chooseSpawn(world)

proc combat(e, p: Entity, index: int) =
    # e: attacking entity 
    # p: defending entity
    # index: index of defending entity
    var
        att = e.att
        def = p.def
        acc = e.acc
    
    if rand(acc) >= def:
        p.hp -= rand(att)
    if index == 0:
        tb.write(0, 30, $p.hp)
    if e == entitySeq[0]:
        lastAction = "You attack the " & p.name

proc dealCollision(e: Entity, index: int) =
    if (index == 0 and player.hp > 0) or index != 0:
        if world[e.pos.y][e.pos.x] == '#':
                if menu == 3 and e == player:
                  worldArr[level][e.pos.y][e.pos.x] = '.'
                e.pos = e.ppos
        elif world[e.pos.y][e.pos.x] == '>' and e == player:
            lastAction = "You descend further... "
            changeLevel()
        else:
            for i in 0..<entitySeq.len():
                if i != index:
                    if entitySeq[i].pos == e.pos:
                        e.pos = e.ppos
                        if e.species != entitySeq[i].species:
                            if time - e.la >= 1.5:
                                combat(e, entitySeq[i], i)
                                e.la = time
                                if entitySeq[i].hp <= 0 and i != 0:
                                    deadEntities.add(i)
                                    if not(((entitySeq[i].ppos.x,entitySeq[i].ppos.y, level)) in goreSeq):
                                      goreSeq.add (entitySeq[i].ppos.x,entitySeq[i].ppos.y, level)
    let 
        x = player.pos.x - player.ppos.x
        y = player.pos.y - player.ppos.y
    if y == -1:
        lastAction = "You walk northwards    "
    elif y == 1:
        lastAction = "You walk southwards    "
    if x == -1:
        lastAction = "You walk westwards     "
    elif x == 1:
        lastAction = "You walk eastwards     "

proc dealEnemies() =
    for i in 1..<entitySeq.len():
        entitySeq[i].ppos = entitySeq[i].pos
        pathing(entitySeq[i])

proc update() =
    deadEntities.setLen(0)
    time = cpuTime()
    dealEnemies()
    for i in 0..<entitySeq.len():
        dealCollision(entitySeq[i], i)
        world[entitySeq[i].pos.y][entitySeq[i].pos.x] = entitySeq[i].species
    for i in 0..<deadEntities.len():
        entitySeq.delete(deadEntities[i]-i)
    camPos = (player.pos.x-4, player.pos.y-4)
    camPos.x = clamp(camPos.x, 0, MapSize - windowSize)
    camPos.y = clamp(camPos.y, 0, MapSize - windowSize)


#--------------------------------\\--------------------------------#

proc exitProc() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

proc main() =
    illwillInit(fullscreen=true)
    hideCursor()
    displayTitleScreen()
    drawInitialTerminal()
    setControlCHook(exitProc)

    while running:
            reset()
            getInput()
            update()
            drawToTerminal()
            inc turns

    exitProc()

main()
