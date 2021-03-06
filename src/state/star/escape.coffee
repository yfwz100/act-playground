Player = require '../../agent/player'
Star  = require '../../agent/star'
Roadlight = require '../../agent/roadlight'


module.exports = class StarEscapeState

  playerStatus:
    textify: (player) -> "HP: #{player.props.hp}\nMP: #{player.state.mp}"
    init: (game, player) ->
      @sprite = game.add.text 16, 16, @textify(player),
        fontSize: '24px'
        fill: '#fff'
    update: (player) ->
      @sprite.text = @textify player

  constructor: ({@over_state, @pass_state}) ->

  init: ->
    @state.lastPlayed = @state.current

  preload: ->
    @load.image 'game-background', 'assets/game-bg.png'
    @load.image 'ground', 'assets/ground.png'
    @load.spritesheet 'star', 'assets/stars.png', 24, 22
    @load.spritesheet 'dude', 'assets/dude.png', 32, 48
    @load.spritesheet 'diamond', 'assets/weapon.png', 64, 64
    @load.image 'roadlight', 'assets/road-light.png'
    @load.image 'roadlight-light', 'assets/roadlight-light.png'

    unless @game.device.desktop
      @load.image 'right', 'assets/right.png'
      @load.image 'left', 'assets/left.png'
      @load.image 'up', 'assets/up.png'

  create: ->
    @physics.startSystem Phaser.Physics.ARCADE

    @character = {}

    # create the background

    @add.sprite 0, 0, 'game-background'

    platforms = @character.platforms = @add.group()
    platforms.enableBody = yes

    ground = platforms.create 0, @world.height - 64, 'ground'
    ground.scale.setTo 2, 2
    ground.body.immovable = yes

    roadlights = @character.roadlights = @add.group()
    roadlights.enableBody = yes

    for i in [0..2]
      roadlight_x = 100 + i * 300
      roadlight_y = @world.height - 64
#      roadlight = roadlights.create roadlight_x, roadlight_y, 'road-light'
#      roadlight.anchor.setTo 0.5, 1
#      roadlight.body.immovable = yes
      roadlight = new Roadlight @, roadlights, roadlight_x, roadlight_y


    # create the characters

    player = new Player @
    @character.player = player.sprite

    stars = @character.stars = @add.group()
    stars.enableBody = on

    for i in [0..24]
      star_x = Math.random() * 20 + (i / 2) * 70
      star_y = 10 + Math.random() * 50
      star_scale = 0.5 + 0.5 * Math.random()
      star = new Star @, stars, star_x, star_y, star_scale

    # create the utilties and context

    @playerStatus.init @, player

    @control =
      left: no
      right: no
      up: no

    @_setupMobileInputs() unless @game.device.desktop

    # create the overlay for end animation.
    @overlay = @make.graphics 0, 0
    @overlay.beginFill '#000', 1
    @overlay.drawRect 0, 0, 800, 600
    @overlay.endFill()
    @overlay.alpha = 0.7

    @gameover = no

  _setupMobileInputs: ->
    @jump_btn = @add.sprite 10, @world.height - 30, 'up'
    @jump_btn.alpha = 0.5
    @jump_btn.anchor.setTo 0, 1
    @jump_btn.inputEnabled  = yes
    @jump_btn.events.onInputOver.add => @control.up = yes
    @jump_btn.events.onInputDown.add => @control.up = yes
    @jump_btn.events.onInputOut.add => @control.up = no
    @jump_btn.events.onInputUp.add => @control.up = no

    @left_btn = @add.sprite @world.width - 110, @world.height - 30, 'left'
    @left_btn.alpha = 0.5
    @left_btn.anchor.setTo 1, 1
    @left_btn.inputEnabled = yes
    @left_btn.events.onInputOver.add => @control.left = yes
    @left_btn.events.onInputDown.add => @control.left = yes
    @left_btn.events.onInputOut.add => @control.left = no
    @left_btn.events.onInputUp.add => @control.left = no

    @right_btn = @add.sprite @world.width - 30, @world.height - 30, 'right'
    @right_btn.alpha = 0.5
    @right_btn.anchor.setTo 1, 1
    @right_btn.inputEnabled = yes
    @right_btn.events.onInputOver.add => @control.right = yes
    @right_btn.events.onInputDown.add => @control.right = yes
    @right_btn.events.onInputOut.add => @control.right = no
    @right_btn.events.onInputUp.add => @control.right = no

  _processInputs: ->
    if @game.device.desktop
      @control.left = @input.keyboard.isDown Phaser.KeyCode.LEFT
      @control.right = @input.keyboard.isDown Phaser.KeyCode.RIGHT
      @control.up = @input.keyboard.isDown Phaser.KeyCode.SPACEBAR

  # updates specific to game logic.
  _gameUpdate: ->
    {player, stars, platforms, roadlights} = @character

    @_processInputs()

    @physics.arcade.overlap stars, stars, (star1, star2) ->
      if star1 isnt star2
        star1.kill()
        star2.kill()

    fighting = @physics.arcade.overlap player, stars, (player, star) ->
      star.agent.fight player.agent
      player.agent.fight star.agent
    , null, @

    lighted = @game.physics.arcade.overlap player, roadlights, (player, light) ->
      light.agent.forceLighted on

    for star in stars.children
      if star.x > player.x - 100
        unless star.body.allowGravity = not lighted
          star.body.velocity = x: 0, y: 0
          star.agent.backToPlace()
      else
        star.body.allowGravity = no
        star.body.velocity = x: 0, y: 0

    @playerStatus.update player.agent

    player.agent.stop()

    # detect left/right moving.
    switch
      when @control.left
        player.agent.walkLeft()
      when @control.right
        player.agent.walkRight()
      when not fighting
        player.agent.still()

    # track jumping
    if @control.up
      player.agent.jump()

    player.agent.update @character
    for star in stars.children
      star.agent.update @character

    if player.agent.props.hp < 0
      @world.addChild @overlay

      @add.tween @overlay
      .from alpha: 0, 1000
      .start()

      player.agent.kill =>
        @state.start @over_state, yes, no, @character

      @gameover = yes

    if player.x >= @world.width - player.width
      @world.addChild @overlay

      @add.tween @overlay
      .from alpha: 0, 1000
      .start()
      .onComplete.add =>
        @state.start @pass_state, yes, no, @character

      @gameover = yes

  update: ->
    {player, stars, platforms, roadlights} = @character

    @physics.arcade.collide player, platforms
    @physics.arcade.collide stars, platforms

    @_gameUpdate() unless @gameover
