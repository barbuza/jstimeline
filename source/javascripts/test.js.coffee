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
