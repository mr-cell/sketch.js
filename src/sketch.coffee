# # Sketch.js (v0.0.2)
#
# **Sketch.js** is a simple jQuery plugin for creating drawable canvases
# using HTML5 Canvas. It supports multiple browsers including mobile 
# devices (albeit with performance penalties).
(($)->
  # ### jQuery('#mycanvas').sketch(options)
  #
  # Given an ID selector for a `<canvas>` element, initialize the specified
  # canvas as a drawing canvas. See below for the options that may be passed in.
  $.fn.sketch = (key, args...)->
    $.error('Sketch.js can only be called on one element at a time.') if this.length > 1
    sketch = this.data('sketch')

    # If a canvas has already been initialized as a sketchpad, calling
    # `.sketch()` will return the Sketch instance (see documentation below)
    # for the canvas. If you pass a single string argument (such as `'color'`)
    # it will return the value of any set instance variables. If you pass
    # a string argument followed by a value, it will set an instance variable
    # (e.g. `.sketch('color','#f00')`.
    if typeof(key) == 'string' && sketch
      if sketch[key]
        if typeof(sketch[key]) == 'function'
          sketch[key].apply sketch, args
        else if args.length == 0
          sketch[key]
        else if args.length == 1
          sketch[key] = args[0]
      else
        $.error('Sketch.js did not recognize the given command.')
    else if sketch
      sketch
    else
      this.data('sketch', new Sketch(this.get(0), key))
      this

  # ## Sketch
  #
  # The Sketch class represents an activated drawing canvas. It holds the
  # state, all relevant data, and all methods related to the plugin.
  class Sketch
    # ### new Sketch(el, opts)
    #
    # Initialize the Sketch class with a canvas DOM element and any specified
    # options. The available options are:
    #
    # * `toolLinks`: If `true`, automatically turn links with href of `#mycanvas`
    #   into tool action links. See below for a description of the available
    #   tool links.
    # * `defaultTool`: Defaults to `marker`, the tool is any of the extensible 
    #   tools that the canvas should default to.
    # * `defaultColor`: The default drawing color. Defaults to black.
    # * `defaultSize`: The default stroke size. Defaults to 5.
    constructor: (el, opts)->
      @el = el
      @canvas = $(el)
      @context = el.getContext '2d'
      @options = $.extend {
        toolLinks: true
        defaultTool: 'marker'
        defaultColor: '#000000'
        defaultSize: 5
        defaultStyle: 'solid'
      }, opts
      @painting = false
      @color = @options.defaultColor
      @size = @options.defaultSize
      @tool = @options.defaultTool
      @style = @options.defaultStyle
      @text = ''
      @actions = []
      @undoneActions = []
      @action = []
      @lineAction = []
      @linePainting = false
      @circleAction = []
      @circlePainting = false
      @rectAction = []
      @rectPainting = false

      @canvas.bind 'click mousedown mouseup mousemove mouseleave mouseout touchstart touchmove touchend touchcancel', @onEvent

      # ### Tool Links
      #
      # Tool links automatically bind `a` tags that have an `href` attribute
      # of `#mycanvas` (mycanvas being the ID of your `<canvas>` element to
      # perform actions on the canvas.
      if @options.toolLinks
        $('body').delegate "a[href=\"##{@canvas.attr('id')}\"]", 'click', (e)->
          $this = $(this)
          $canvas = $($this.attr('href'))
          sketch = $canvas.data('sketch')
          # Tool links are keyed off of HTML5 `data` attributes. The following
          # attributes are supported:
          #
          # * `data-tool`: Change the current tool to the specified value.
          # * `data-color`: Change the draw color to the specified value.
          # * `data-size`: Change the stroke size to the specified value.
          # * `data-download`: Trigger a sketch download in the specified format.
          for key in ['color', 'size', 'tool', 'style']
            if $this.attr("data-#{key}")
              sketch.set key, $(this).attr("data-#{key}")
          if $(this).attr('data-download')
            sketch.download $(this).attr('data-download')
          false

    # ### sketch.download(format)
    #
    # Cause the browser to open up a new window with the Data URL of the current
    # canvas. The `format` parameter can be either `png` or `jpeg`.
    download: (format)->
      format or= "png"
      format = "jpeg" if format == "jpg"
      mime = "image/#{format}"
      window.open @el.toDataURL(mime)

    # ### sketch.set(key, value)
    #
    # *Internal method.* Sets an arbitrary instance variable on the Sketch instance
    # and triggers a `changevalue` event so that any appropriate bindings can take
    # place.
    set: (key, value)->
      this[key] = value
      @canvas.trigger("sketch.change#{key}", value)

    # ### sketch.startPainting()
    #
    # *Internal method.* Called when a mouse or touch event is triggered 
    # that begins a paint stroke. 
    startPainting: ->
      @painting = true
      @action = {
        tool: @tool
        color: @color
        size: parseFloat(@size)
        style: @style
        events: []
      }

    # ### sketch.stopPainting()
    #
    # *Internal method.* Called when the mouse is released or leaves the canvas.
    stopPainting: ->
      @actions.push @action if @action
      @painting = false
      @action = null
      @redraw()

    startLine: ->
      @linePainting = true
      @lineAction = {
        tool: @tool
        color: @color
        size: parseFloat(@size)
        style: @style
        events: []
      }

    stopLine: ->
      @actions.push @lineAction if @lineAction
      @linePainting = false
      @lineAction = null
      @redraw()

    startCircle: ->
      @circlePainting = true
      @circleAction = {
        tool: @tool
        color: @color
        size: parseFloat(@size)
        style: @style
        events: []
      }

    stopCircle: ->
      @actions.push @circleAction if @circleAction
      @circlePainting = false
      @circleAction = null
      @redraw()

    startRect: ->
      @rectPainting = true
      @rectAction = {
        tool: @tool
        color: @color
        size: parseFloat(@size)
        style: @style
        events: []
      }

    stopRect: ->
      @actions.push @rectAction if @rectAction
      @rectPainting = false
      @rectAction = null
      @redraw()

    pointDistance: (point1, point2)->
      xs = point2.x - point1.x
      ys = point2.y - point1.y
      Math.sqrt((xs * xs) + (ys * y2))

    calculateLineStyle: (style, size) ->
      result = []
      if style is 'dashed'
        result[0] = 3 * size
        result[1] = 3 * size
      else if style is 'dotted'
        result[0] = 1
        result[1] = 2 * size
      result

    drawArrowAtBeginningOfLine: (startX, startY, endX, endY, arrowSize) ->
      angleRight = 1 - Math.atan2 endX - startX, endY - startY
      angleLeft = 1 - Math.atan2 endY - startY, endX - startX
      @context.moveTo startX, startY
      @context.lineTo endX - arrowSize * Math.cos(angleRight), endY - arrowSize * Math.sin(angleRight)
      @context.moveTo endX, endY
      @context.lineTo endX - arrowSize * Math.sin(angleLeft), endY - arrowSize * Math.cos(angleLeft)

    drawArrowAtEndOfLine: (startX, startY, endX, endY, arrowSize) ->
      angleRight = 1 - Math.atan2 endX - startX, endY - startY
      angleLeft = 1 - Math.atan2 endY - startY, endX - startX
      @context.moveTo endX, endY
      @context.lineTo endX - arrowSize * Math.cos(angleRight), endY - arrowSize * Math.sin(angleRight)
      @context.moveTo endX, endY
      @context.lineTo endX - arrowSize * Math.sin(angleLeft), endY - arrowSize * Math.cos(angleLeft)

    # ### sketch.onEvent(e)
    #
    # *Internal method.* Universal event handler for the canvas. Any mouse or 
    # touch related events are passed through this handler before being passed
    # on to the individual tools.
    onEvent: (e)->
      if e.originalEvent && e.originalEvent.targetTouches
        e.pageX = e.originalEvent.targetTouches[0].pageX
        e.pageY = e.originalEvent.targetTouches[0].pageY
      $.sketch.tools[$(this).data('sketch').tool].onEvent.call($(this).data('sketch'), e)
      e.preventDefault()
      false

    # ### sketch.redraw()
    #
    # *Internal method.* Redraw the sketchpad from scratch using the aggregated
    # actions that have been stored as well as the action in progress if it has
    # something renderable.
    redraw: ->
      @context = @el.getContext '2d'
      @context.clearRect 0, 0, @el.width, @el.height
      sketch = this
      $.each @actions, ->
        if this.tool
          $.sketch.tools[this.tool].draw.call sketch, this
      return $.sketch.tools[@action.tool].draw.call sketch, @action if @painting && @action
      return $.sketch.tools[@lineAction.tool].draw.call sketch, @lineAction if @linePainting && @lineAction
      return $.sketch.tools[@circleAction.tool].draw.call sketch, @circleAction if @circlePainting && @circleAction
      return $.sketch.tools[@rectAction.tool].draw.call sketch, @rectAction if @rectPainting && rectAction

  # # Tools
  #
  # Sketch.js is built with a pluggable, extensible tool foundation. Each tool works
  # by accepting and manipulating events registered on the sketch using an `onEvent`
  # method and then building up **actions** that, when passed to the `draw` method,
  # will render the tool's effect to the canvas. The tool methods are executed with
  # the Sketch instance as `this`.
  #
  # Tools can be added simply by adding a new key to the `$.sketch.tools` object.
  $.sketch = { tools: {} }
  
  # ## marker
  #
  # The marker is the most basic drawing tool. It will draw a stroke of the current
  # width and current color wherever the user drags his or her mouse.
  $.sketch.tools.marker =
    onEvent: (e)->
      switch e.type
        when 'mousedown', 'touchstart'
          @startPainting()
        when 'mouseup', 'mouseout', 'mouseleave', 'touchend', 'touchcancel'
          @stopPainting()
      if @painting
        @action.events.push
          x: e.pageX - @canvas.offset().left
          y: e.pageY - @canvas.offset().top
          event: e.type
        @redraw()
    draw: (action)->
      @context.lineJoin = "round"
      @context.lineCap = "round"
      lineStyle = @calculateLineStyle action.style, action.size
      @context.beginPath()
      @context.setLineDash lineStyle      
      @context.moveTo action.events[0].x, action.events[0].y
      for event in action.events
        @context.lineTo event.x, event.y
        previous = event
      @context.strokeStyle = action.color
      @context.lineWidth = action.size
      @context.stroke()

  $.sketch.tools.line =
    onEvent: (e) ->
      switch e.type
        when 'mousedown', 'touchstart'
          @startLine()
        when 'mouseup', 'mouseout', 'mouseleave', 'touchend', 'touchcancel'
          @stopLine()
      if @linePainting
        @lineAction.events.pop() if @lineAction.events.length > 1
        @lineAction.events.push
          x: e.pageX - @canvas.offset().left
          y: e.pageY - @canvas.offset().top
          event: e.type
        @redraw()
    draw: (action) ->
      @context.lineJoin = 'round'
      @context.lineCap = 'round'
      lineStyle = @calculateLineStyle action.style, action.size
      @context.beginPath()
      @context.setLineDash lineStyle
      @context.moveTo action.events[0].x, action.events[0].y
      for event in action.events
        @drawArrowAtBeginningOfLine(action.events[0].x, action.events[0].y event.x, event.y, action.size * 4) if action.drawStartAction
        @context.lineTo event.x, event.y
        @drawArrowAtEndOfLine(action.events[0].x, action.events[0].y, event.x, event.y, action.size * 4) if action.drawEndArrow
          previous = event
      @context.strokeStyle = action.color
      @context.lineWidth = action.size
      @context.stroke()

  $.sketch.tools.arrow_line =
    onEvent: (e) ->
      $.sketch.tools.line.onEvent.call @, each
    draw: (action) ->
      action.drawEndArrow = true
      $.sketch.tools.line.draw.call @, action

  $.sketch.tools.double_arrow_line =
    onEvent: (e) ->
      $.sketch.tools.line.onEvent.call @, each
    draw: (action) ->
      action.drawStartArrow = true
      action.drawEndArrow = true
      $.sketch.tools.line.draw.call @, action

  $.sketch.tools.circle = 
    onEvent: (e) ->
      switch e.type
        when 'mousedown', 'touchstart'
          @startCircle()
        when 'mouseup', 'mouseout', 'mouseleave', 'touchend', 'touchcancel'
          @stopCircle()
      if @circlePainting
        @circleAction.events.pop() if @circleAction.events.length > 1
        @circleAction.events.push
          x: e.pageX - @canvas.offset().left
          y: e.pageY - @canvas.offset().top
          event: e.type
        @redraw()
    draw: (action) ->
      @context.lineJoin = 'round'
      @context.lineCap = 'round'
      lineStyle = @calculateLineStyle action.style, action.size
      @context.beginPath()
      @context.setLineDash lineStyle
      for event in action.events
        radius = @pointDistance {
          x: action.events[0].x
          y: action.events[0].y
        }, {
          x: event.x
          y: event.y
        }
        @context.arc action.events[0].x, action.events[0].y, radius, 0, 2 * Math.PI
        previous = event
      @context.strokeStyle = action.color
      @context.lineWidth = action.size
      @context.stroke()

  $.sketch.tools.rectangle = 
    onEvent: (e) ->
      switch e.type
        when 'mousedown', 'touchstart'
          @startRect()
        when 'mouseup', 'mouseout', 'mouseleave', 'touchend', 'touchcancel'
          @stopRect()

      if @rectPainting
        @rectAction.events.pop() if @rectAction.events.length > 1
        @rectAction.events.push
          x: e.pageX - @canvas.offset().left
          y: e.pageY - @canvas.offset().top
          event: e.type
        @redraw()
    draw: (action) ->
      @context.lineJoin = 'round'
      @context.lineCap = 'round'
      lineStyle = @calculateLineStyle action.style, action.size
      @context.beginPath()
      @context.setLineDash lineStyle
      for event in action.events
        width = event.x - action.events[0].x
        height = event.y - action.events[0].y
        @context.rect action.events[0].x, action.events[0].y, width, height
        previous = event
      @context.strokeStyle = action.color
      @context.lineWidth = action.size
      @context.stroke()

  @.sketch.tools.text =
    onEvent: (e) ->
      switch e.type
        when 'mouseup', 'touchend'
          @action = {
            tool: @tool
            color: @color
            text: @text
            size: parseFloat(@size)
            events: []
          }
          @action.events.push
            x: e.pageX - @canvas.offset().left
            y: e.pageY - @canvas.offset().top
            event: e.type
          @actions.push @action
          @action = null
      @redraw()
    draw: (action) ->
      @context.font = '20px SansSerif'
      @context.fillStyle = action.color
      for event in action.events
        @context.fillText action.text, event.x, event.y
        previous = event

  $.sketch.tools.undo =
    onEvent: (e) ->
      switch e.type
        when 'mouseup', 'touchend'
          lastAction = @actions.pop()
          @undoneActions.push lastAction if lastAction
      @redraw()
    draw: (action) ->

  $.sketch.tools.redo =
    onEvent: (e) ->
      switch e.type
        when 'mouseup', 'touchend'
          lastAction = @undoneActions.pop()
          actions.push lastAction if lastAction
      @redraw()
    draw: (action) ->

  # ## eraser
  #
  # The eraser does just what you'd expect: removes any of the existing sketch.
  $.sketch.tools.eraser =
    onEvent: (e)->
      $.sketch.tools.marker.onEvent.call this, e
    draw: (action)->
      oldcomposite = @context.globalCompositeOperation
      @context.globalCompositeOperation = "destination-out"
      action.color = "rgba(0,0,0,1)"
      $.sketch.tools.marker.draw.call this, action
      @context.globalCompositeOperation = oldcomposite
)(jQuery)