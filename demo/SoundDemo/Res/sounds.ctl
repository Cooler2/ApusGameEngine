# ---------------------------------------------- #
#        Sounds and music definitions            #
# ---------------------------------------------- #

$Section Settings
  ; samples to load in advance: a comma-separated list of files, ALL or NONE
  PreloadSamples        "sample.ogg"
$EndOfSection


$Section Music
  $Section TestOGG
    File     "music.ogg"
    volume   50
    loop     ON
  $EndOfSection

  $Section TestMP3
    File     "musicLow.mp3"
    volume   50
    loop     OFF
  $EndOfSection

  $Section TestLoop
    File     "loop.wav"
    volume   50
    loop     ON
    ; loop start in samples: the 0.5 s intro plays once
    loopPos  22050
  $EndOfSection

  $Section TestLoopTime
    File     "loop.wav"
    volume   50
    loop     ON
    ; the same loop start in seconds
    loopTime 0.5
  $EndOfSection

  $Section TestLoopBad
    File     "loop.wav"
    volume   50
    loop     ON
    ; the loop start is 2 ms late: the phase jumps, a click every second
    loopTime 0.502
  $EndOfSection

  $Section TestMOD
    File     "x-tag.mod"
    volume   50
  $EndOfSection

$EndOfSection


$Section SoundEvents
  ; Format: EventName  "filename,vol=xx,pan=yy"
  Sample    "sample.ogg"
  Low       "sampleLow.ogg"
  Stereo    "sampleStereo.ogg"
  Wav       "sampleWav.wav"
  sampleQuiet "sample.ogg,vol=30"
  sampleLeft  "sample.ogg,pan=-90"
$EndOfSection
