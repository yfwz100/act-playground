module.exports = class NarratorState

  name: 'narrator'

  constructor: ({@scripts, @next_state}) ->

  preload: ->
    for script in @scripts
      if script.image
        @load.image script.image.name, script.image.url

  create: ->
    @index = 0

    if @scripts.length > 0
      current_script = @scripts[@index]

      # create the screen image.
      @screen = @add.button 0, 0, current_script.image?.name, ->
        unless @text_fade.isRunning
          @index += 1
          if @index < @scripts.length
            script = @scripts[@index]
            # image fades if image exists.
            if script.image
              @screen_fade.start()
            # text fade always runs.
            @text_fade.start()
          else
            # exit the state.
            @add.tween @screen
            .to alpha: 0, 500
            .start()
            .onComplete.add =>
              @state.start @next_state
            @add.tween @text
            .to alpha: 0, 500
            .start()
      , @
      @screen.alpha = 0
      @screen.hitArea = new PIXI.Rectangle(0, 0, 800, 600)

      # create the description text.
      text_x = @world.centerX
      text_y = @world.centerY
      @text = @add.text text_x, text_y, current_script.description?.text,
        fontSize: '36pt'
        fill: '#fff'
      @text.anchor.setTo 0.5, 0.5
      @text.alpha = 0

      screen_in = @add.tween @screen
      .to alpha: 1, 500
      .start()

      @screen_fade = @add.tween @screen
      .to alpha: 0, 500
      .chain screen_in

      @screen_fade.onComplete.add ->
        if @index < @scripts.length
          @screen.loadTexture @scripts[@index].image.name
      , @

      text_in = @add.tween @text
      .to alpha: 1, 500
      .start()

      @text_fade = @add.tween @text
      .to alpha: 0, 500
      .chain text_in

      @text_fade.onComplete.add ->
        script = @scripts[@index]
        if script.description
          @text.text = script.description.text
          @text.x = script.description.x or @world.centerX
          @text.y = script.description.y or @world.centerY
        else
          @text.text = ''
      , @

    else
      @state.start @next_state
