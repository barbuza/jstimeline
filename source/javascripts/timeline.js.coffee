
Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}


Function::registerEvent = (name) ->
  @prototype["_handlers_#{name}"] = []
  capitalized = name.slice(0, 1).toUpperCase() + name.slice(1)

  @prototype["on#{capitalized}"] = (handler) ->
    @["_handlers_#{name}"].push handler
    null

  @prototype["dispatch#{capitalized}"] = (args...) ->
    for handler in @["_handlers_#{name}"]
      handler(args...)
    null


$ = jQuery

class window.Timeline

  position: 0
  size: 100
  time: 0
  items: {}
  selected: null
  nextItemId: 0

  @registerEvent "play"
  @registerEvent "pause"
  @registerEvent "setTime"
  @registerEvent "itemAdded"
  @registerEvent "itemDeleted"
  @registerEvent "itemChanged"

  constructor: ->
    @root = $ "<div class='timeline'></div>"
    @controls = $ "<div class='controls'></div>"
    @controls.mousedown -> no
    @times = $ "<div class='times'></div>"
    @times_handle = $ "<div class='times-handle'></div>"
    @current = $ "<div class='current'></div>"
    @root.append @controls, @times, @current, @times_handle
    @root.bind "mousedown.move", (e) => @startMoving e
    @root.bind "mousewheel.scale", (e) => @doScale e
    @times_handle.bind "mousedown.settime", (e) => @setTime e
    @createControls()

  createControls: ->
    @splitBtn = $ "<div class='split disabled'>split</div>"
    @splitBtn.click (e) =>
      @splitControlClick e unless @splitBtn.hasClass "disabled"
    @deleteBtn = $ "<div class='delete disabled'>delete</div>"
    @deleteBtn.click (e) =>
      @deleteControlClick e unless @deleteBtn.hasClass "disabled"
    @playBtn = $ "<div class='play'>play</div>"
    @playBtn.click (e) =>
      if @playBtn.text() == "play"
        @playBtn.text "pause"
      else
        @playBtn.text "play"
    @controls.append @playBtn, @splitBtn, @deleteBtn

  enableControls: (names...) ->
    for name in names
      @controls.find(".#{name}").removeClass "disabled"

  disableControls: (names...) ->
    for name in names
      @controls.find(".#{name}").addClass "disabled"

  formatTime: (val) ->
    minutes = Math.floor val / (25 * 60)
    rest = val - minutes * 25 * 60
    seconds = Math.floor rest / 25
    rest = val - minutes * 28 * 60 - seconds * 25
    minutes = "0#{minutes}" if minutes < 10
    seconds = "0#{seconds}" if seconds < 10
    if parseInt minutes
      "#{minutes}:#{seconds}"
    else
      msec = ("" + rest * 400).slice(0, 1)
      "#{minutes}:#{seconds}.#{msec}"

  @getter "width", -> @root.width() + 1
  @getter "scale", -> Math.ceil 5 * @size / @width
  @getter "markStep", -> Math.floor @width * @scale / @size

  getShift: (e) -> Math.floor( (e.clientX - @moveStartX) * @size / @width )    

  setTime: (e) ->
    @time = @screenToValue e.offsetX
    @redrawCurrentTime()
    @checkSplitPosibility()
    @dispatchSetTime @time
    no

  checkSplitPosibility: ->
    unless @selected
      @disableControls "split"
      return
    position = @selected.data "position"
    size = @selected.data "size"
    if @time - position >= 5 and position + size - @time >= 5
      @enableControls "split"
    else
      @disableControls "split"

  startMoving: (e) ->
    @root.addClass "move"
    $(document.body).bind "mouseup.move", (e) => @stopMoving e
    @root.bind "mousemove.move", (e) => @doMove e
    @moveStartX = e.clientX
    @moveStartPos = @position
    @selected?.removeClass "selected"
    if @selected
      @redrawItem @selected
      @selected = null
      @disableControls "split", "delete"

  stopMoving: (e) ->
    @root.removeClass "move"
    $(document.body).unbind ".move"
    @root.unbind ".move"
    @root.bind "mousedown.move", (e) => @startMoving e

  doMove: (e) ->
    @position = @moveStartPos + @getShift(e)
    @position = 0 if @position < 0
    @redraw()

  startMovingItem: (item, e) ->
    if item.hasClass "selected"
      @moveStartX = e.clientX
      @moveStartSize = item.data "size"
      @moveStartPos = item.data "position"
      $(document.body).bind "mouseup.moveitem", (e) => @stopMovingItem item, e
      item.addClass "change"
      if e.offsetX < 10
        @root.bind "mousemove.moveitem", (e) => @doWResizeItem item, e
      else if item.outerWidth() - e.offsetX < 10
        @root.bind "mousemove.moveitem", (e) => @doEResizeItem item, e
      else
        @root.bind "mousemove.moveitem", (e) => @doMoveItem item, e
    else
      @selected?.removeClass "selected"
      @selected = item
      @enableControls "delete"
      @checkSplitPosibility()
      item.addClass "selected"
      @redraw()
    no

  stopMovingItem: (item, e) ->
    @root.unbind ".moveitem"
    $(document.body).unbind ".moveitem"
    item.removeClass "change"

  trySetItemAttrs: (item, {size, position, siblings}) ->
    return no if size < 5
    left = position or item.data("position")
    right = (size or item.data("size")) + left
    for sibling in (siblings or item.siblings())
      s_left = $(sibling).data "position"
      s_right = $(sibling).data("size") + s_left
      return no if s_left < left < s_right or s_left < right < s_right or left < s_left < right or left < s_right < right
    item.data
      position: position or item.data("position")
      size: size or item.data("size")
    @dispatchItemChanged item.data("id"), item.data("position"), item.data("size")
    @checkSplitPosibility()
    @redrawItem item
    yes

  doMoveItem: (item, e) ->
    @trySetItemAttrs item,
      position: @moveStartPos + @getShift(e)

  doWResizeItem: (item, e) ->
    shift = @getShift e
    @trySetItemAttrs item,
      position: @moveStartPos + shift
      size: @moveStartSize - shift

  doEResizeItem: (item, e) ->
    @trySetItemAttrs item,
      size: @moveStartSize + @getShift(e)

  doScale: (e) ->
    delta = e.originalEvent.wheelDelta
    if delta < 0
      @size *= 1.05
    else if delta > 0
      @size /= 1.05
    @size = 100 if @size < 100
    @redraw()
    no

  splitControlClick: ->
    if @selected
      item = @selected
      @selected = null
      item.removeClass "selected"
      position = item.data "position"
      size = item.data "size"
      first_size = @time - position
      if @trySetItemAttrs(item, size: first_size)
        item.removeClass "selected"
        second_position = @time
        second_size = size - first_size
        @addItem item.data("type"), second_position, second_size, item.data("name"), item.data("props")
    @disableControls "split"

  deleteControlClick: ->
    if @selected
      id = @selected.data "id"
      @selected.remove()
      @selected = null
      @dispatchItemDeleted id
      @redraw()
    @disableControls "delete", "split"

  addItem: (type, position, size, name) ->
    row = if type is "video" then @nextVideoRow() else @nextAudioRow()
    row.append @createItem(type, position, size, name)
    @redraw()

  createItem: (type, position, size, name, props={}) ->
    item = $ "<div>#{name}</div>"
    item.data "type", type
    item.data "name", name
    item.data "position", position
    item.data "size", size
    item.data "props", props
    item.data "id", ++@nextItemId
    item.bind "mousedown.move", (e) => @startMovingItem item, e
    item.bind "mousemove.cursor", (e) => @setItemCursor item, e
    @dispatchItemAdded item.data("id"), item.data("position"), item.data("size"), item.data("props")
    item

  setItemCursor: (item, e) ->
    item.removeClass("w-resize").removeClass("e-resize").removeClass("move").removeClass("hover")
    if item.hasClass "selected"
      if e.offsetX < 10
        item.addClass "w-resize"
      else if item.outerWidth() - e.offsetX < 10
        item.addClass "e-resize"
      else
        item.addClass "move"
    else
      item.addClass "hover"

  redraw: ->
    for item in @root.find ".row div"
      @redrawItem $ item
    @redrawMarks()
    @redrawCurrentTime()

  redrawCurrentTime: ->
    @current.css
      left: Math.floor (@time - @position) * @markStep / @scale - 1
      width: if @scale is 1 then @markStep else 1
      opacity: if @scale is 1 then 0.5 else 1

  valueToScreen: (val) -> Math.floor (val - @position) * @markStep / @scale

  screenToValue: (screen) -> Math.floor screen * @scale / @markStep + @position

  redrawItem: (item) ->
    item.css
      "width": Math.floor item.data("size") * @markStep / @scale - (if @scale is 1 then 1 else 0) - (if item.hasClass "selected" then 4 else 0)
      "left": @valueToScreen item.data("position")

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
  t.time = 32
  t.inject $ document.body
  t.addItem "video", 10, 30, "video1"
  t.addItem "video", 60, 20, "video2"
  t.addItem "audio", 8, 40, "audio1"
  t.addItem "audio", 61, 20, "audio2"
  t.addItem "audio", 61, 20, "audio3"
  window.t = t
