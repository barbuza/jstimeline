
Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}


class Timeline

  position: 0
  size: 100
  items: {}

  constructor: ->
    @root = $ "<div class='timeline'></div>"
    @times = $ "<div class='times'></div>"
    @root.append @times
    @root.bind "mousedown.move", (e) => @startMoving e
    @root.bind "mousewheel.scale", (e) => @doScale e

  formatTime: (val) ->
    minutes = Math.floor val / (25 * 60)
    rest = val - minutes * 25 * 60
    seconds = Math.floor rest / 25
    rest = val - minutes * 28 * 60 - seconds * 25
    minutes = "0#{minutes}" if minutes < 10
    seconds = "0#{seconds}" if seconds < 10
    msec = ("" + rest * 400).slice(0, 2)
    return "#{minutes}:#{seconds}.#{msec}"

  @getter "width", -> @root.width()
  @getter "scale", -> Math.ceil 5 * @size / @width
  @getter "markStep", -> Math.floor @width * @scale / @size

  startMoving: (e) ->
    $(document.body).bind "mouseup.move", (e) => @stopMoving e
    @root.bind "mousemove.move", (e) => @doMove e
    @moveStartX = e.clientX
    @moveStartPos = @position

  stopMoving: (e) ->
    $(document.body).unbind ".move"
    @root.unbind ".move"
    @root.bind "mousedown.move", (e) => @startMoving e

  doMove: (e) ->
    shift = Math.floor( (e.clientX - @moveStartX) * @size / @width )
    @position = @moveStartPos + shift
    @position = 0 if @position < 0
    @redraw()

  startMovingItem: (item, e) ->
    @moveStartX = e.clientX
    @moveStartSize = item.data "size"
    @moveStartPos = item.data "position"
    $(document.body).bind "mouseup.moveitem", (e) => @stopMovingItem item, e
    if e.offsetX < 10
      @root.bind "mousemove.moveitem", (e) => @doWResizeItem item, e
    else if item.outerWidth() - e.offsetX < 10
      @root.bind "mousemove.moveitem", (e) => @doEResizeItem item, e
    else
      @root.bind "mousemove.moveitem", (e) => @doMoveItem item, e
    no

  stopMovingItem: (item, e) ->
    @root.unbind ".moveitem"
    $(document.body).unbind ".moveitem"
    item.removeClass "move"

  checkSiblings: (item, {size, position}) ->
    left = position || item.data("position")
    right = (size || item.data("size")) + left
    for sibling in item.siblings()
      s_left = $(sibling).data "position"
      s_right = $(sibling).data("size") + s_left
      return no if s_left < left < s_right or s_left < right < s_right or left < s_left < right or left < s_right < right
    yes

  doMoveItem: (item, e) ->
    shift = Math.floor( (e.clientX - @moveStartX) * @size / @width)
    if @checkSiblings(item, position: @moveStartPos + shift)
      item.data "position", @moveStartPos + shift
      @redraw()

  doWResizeItem: (item, e) ->
    shift = Math.floor( (e.clientX - @moveStartX) * @size / @width)
    if @checkSiblings(item, position: @moveStartPos + shift, size: @moveStartSize - shift)
      item.data "position", @moveStartPos + shift
      item.data "size", @moveStartSize - shift
      @redraw()

  doEResizeItem: (item, e) ->
    shift = Math.floor( (e.clientX - @moveStartX) * @size / @width)
    if @checkSiblings(item, size: @moveStartSize + shift)
      item.data "size", @moveStartSize + shift
      @redraw()

  doScale: (e) ->
    delta = e.originalEvent.wheelDelta
    if delta < 0
      @size *= 1.05
    else if delta > 0
      @size /= 1.05
    @size = 100 if @size < 100
    @redraw()
    no

  addItem: (type, position, size, name) ->
    row = if type is "video" then @nextVideoRow() else @nextAudioRow()
    row.append @createItem(position, size, name)
    @redraw()

  createItem: (position, size, name) ->
    item = $ "<div>#{name}</div>"
    item.data "name", name
    item.data "position", position
    item.data "size", size
    item.bind "mousedown.move", (e) => @startMovingItem item, e
    item.bind "mousemove.cursor", (e) => @setItemCursor item, e
    item

  setItemCursor: (item, e) ->
    if e.offsetX < 10
      item.attr "class", "w-resize"
    else if item.outerWidth() - e.offsetX < 10
      item.attr "class", "e-resize"
    else
      item.attr "class", "move"

  redraw: ->
    for item in @root.find ".row div"
      @redrawItem $ item
    @redrawMarks()

  redrawItem: (item) ->
    item.css
      "width": Math.floor item.data("size") * @markStep / @scale
      "left": Math.floor (item.data("position") - @position) * @markStep / @scale

  redrawMarks: ->
    @root.css
      "background-position": "#{-@position * @markStep / @scale}px 0px, 0px 0px, #{-@position * @markStep / @scale}px 0px"
      "background-size": "#{@markStep * 10}px 100%, 100% 25px, #{@markStep}px 100%"
      "background-image": "-webkit-linear-gradient(left, transparent #{@markStep * 10 - 1}px, rgba(100, 100, 100, 0.6) 1px)," +
                          "-webkit-linear-gradient(left, #fff, #fff)," +
                          "-webkit-linear-gradient(left, transparent #{@markStep - 1}px, rgba(100, 100, 100, 0.2) 1px)"
    @times.empty()
    val = 0
    while true
      val += @scale * 10
      left = (val - @position) * @markStep / @scale
      break if left > @width
      mark = $ "<div class='mark'>#{@formatTime val}</div>"
      @times.append mark
      left = left - mark.outerWidth() / 2
      right = left + mark.outerWidth()
      mark.css "left", left

  nextVideoRow: ->
    unless @root.find(" > .row.video").length
      row = $ "<div class='row video'></div>"
      @root.append row
    @root.find(" > .row.video")

  nextAudioRow: ->
    row = $ "<div class='row audio'></div>"
    @root.append row
    @root.find(" > .row.audio:last")

  inject: (target) ->
    target.append @root
    @redraw()


jQuery ->
  t = new Timeline
  t.inject $ document.body
  t.addItem "video", 10, 30, "video1"
  t.addItem "video", 60, 20, "video2"
  t.addItem "audio", 8, 40, "audio1"
  t.addItem "audio", 61, 20, "audio2"
  t.addItem "audio", 61, 20, "audio3"
